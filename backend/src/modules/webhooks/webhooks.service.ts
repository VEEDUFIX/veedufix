import { BookingStatus, PaymentStatus, Prisma } from "@prisma/client";
import { createHash, createHmac, timingSafeEqual } from "crypto";
import { AppError } from "../../lib/app-error.js";
import { env } from "../../config/env.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { redis } from "../../lib/redis.js";
import {
  publishNotificationEvent,
  publishTrackingEvent
} from "../../lib/realtime.js";
import { recordBookingTimelineEvent } from "../../lib/booking-timeline.js";
import { dispatchBookingAfterPayment } from "../matching/matching.service.js";
import { raiseOpsAlert } from "../ops/ops.service.js";
import { settleRefundFromProvider } from "../refund/refund.service.js";
import { settleWalletPayoutFromProvider } from "../wallet/wallet.service.js";

type RazorpayWebhookEvent = {
  event?: string;
  payload?: {
    refund?: {
      entity?: {
        id?: string;
        payment_id?: string;
        amount?: number;
        currency?: string;
        status?: string;
        notes?: Record<string, string>;
      };
    };
    payment?: {
      entity?: {
        id?: string;
        order_id?: string;
        amount?: number;
        currency?: string;
        status?: string;
      };
    };
    order?: {
      entity?: {
        id?: string;
        amount?: number;
        currency?: string;
        status?: string;
      };
    };
    payout?: {
      entity?: {
        id?: string;
        reference_id?: string;
        status?: string;
        error_description?: string;
        notes?: Record<string, string>;
      };
    };
  };
};

type RazorpayPayoutEntity = {
  id?: string;
  reference_id?: string;
  status?: string;
  error_description?: string;
  notes?: Record<string, string>;
};

type PaymentWithBooking = Prisma.PaymentGetPayload<{
  include: { booking: true };
}>;

function verifyWebhookSignature(rawBody: string, signature: string): boolean {
  if (!env.RAZORPAY_WEBHOOK_SECRET) {
    throw new AppError(500, "Razorpay webhook secret is not configured");
  }

  const expected = createHmac("sha256", env.RAZORPAY_WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");

  if (!/^[a-f\d]{64}$/i.test(signature)) return false;
  return timingSafeEqual(Buffer.from(expected, "hex"), Buffer.from(signature, "hex"));
}

async function claimWebhookDelivery(rawBody: string, signature: string): Promise<string | null> {
  const digest = createHash("sha256")
    .update(rawBody)
    .update("|")
    .update(signature)
    .digest("hex");

  const key = `webhook:razorpay:${digest}`;
  const result = await redis.set(key, "1", "EX", 24 * 60 * 60, "NX");
  return result === "OK" ? key : null;
}

function compactNotes(notes: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(notes).filter(([, value]) => value !== undefined && value !== null)
  );
}

function asJsonInput(value: Record<string, unknown>): Prisma.InputJsonValue {
  return value as Prisma.InputJsonValue;
}

function toPaise(amount: Prisma.Decimal | number | string): number {
  const value = typeof amount === "number" ? amount : Number(amount);
  return Math.max(0, Math.round(value * 100));
}

async function notifyUser(userId: string, title: string, body: string, data?: Record<string, unknown>) {
  const jsonData = data ? (data as Prisma.InputJsonValue) : undefined;

  await prisma.notification.create({
    data: {
      userId,
      title,
      body,
      type: "PAYMENT",
      ...(jsonData ? { data: jsonData } : {})
    }
  });

  await publishNotificationEvent({
    userId,
    title,
    body,
    type: "PAYMENT",
    data: data ?? null
  });
}

function getPaymentNotes(payment: PaymentWithBooking): Record<string, unknown> {
  if (payment.notes && typeof payment.notes === "object") {
    return payment.notes as Record<string, unknown>;
  }

  return {};
}

function mergePaymentNotes(payment: PaymentWithBooking, notes: Record<string, unknown>): Prisma.InputJsonValue {
  return {
    ...getPaymentNotes(payment),
    ...compactNotes(notes)
  } as Prisma.InputJsonValue;
}

async function findPaymentForRazorpayPaymentId(paymentId: string): Promise<PaymentWithBooking | null> {
  const payments = await prisma.payment.findMany({
    where: {
      provider: "RAZORPAY"
    },
    include: {
      booking: true
    }
  });

  for (const payment of payments) {
    if (payment.providerRef === paymentId) {
      return payment;
    }

    const notes = getPaymentNotes(payment);
    if (String(notes.paymentId ?? "") === paymentId) {
      return payment;
    }
  }

  return null;
}

function isCancelledBookingStatus(status: BookingStatus): boolean {
  return status === BookingStatus.CANCELLED ||
    status === BookingStatus.CANCELLED_MANUAL ||
    status === BookingStatus.CANCELLED_NO_SHOW;
}

async function flagPaymentCapturedAfterCancellation(
  payment: PaymentWithBooking,
  orderId: string,
  notes: Record<string, unknown>,
  notifyCustomer: boolean
): Promise<void> {
  const paymentId = String(notes.paymentId ?? payment.id);
  await raiseOpsAlert({
    type: "payment_mismatch",
    sourceId: `payment-after-cancellation:${payment.id}`,
    bookingId: payment.bookingId,
    severity: "critical",
    message: `Payment was captured for cancelled booking ${payment.booking.code}; review refund eligibility.`,
    metadata: {
      title: "Payment captured after cancellation",
      bookingCode: payment.booking.code,
      customerId: payment.booking.customerId,
      amount: Number(payment.booking.totalAmount),
      orderId,
      paymentId,
      retryAvailable: false
    }
  });
  if (!notifyCustomer) return;

  await publishTrackingEvent({
    bookingId: payment.bookingId,
    bookingCode: payment.booking.code,
    status: "PAYMENT_CAPTURED_AFTER_CANCELLATION",
    message: "Payment captured after the booking was cancelled; refund review is required",
    paymentId
  });
  await notifyUser(
    payment.booking.customerId,
    "Payment needs review",
    `Payment for cancelled booking ${payment.booking.code} was received. Our team will review the refund eligibility.`,
    { bookingId: payment.bookingId, orderId, paymentId }
  );
}

export async function updatePaymentForWebhook(
  orderId: string,
  status: PaymentStatus,
  notes: Record<string, unknown>,
  capturedAmountPaise?: number
) {
  const payment = await prisma.payment.findUnique({
    where: { providerRef: orderId },
    include: { booking: true }
  });

  if (!payment) {
    logger.warn({ orderId, status }, "Webhook received for unknown payment");
    return null;
  }

  // Razorpay captures only the non-wallet portion of the booking total.
  const expectedAmountPaise = toPaise(payment.amount);
  const recordedAmountPaise = toPaise(payment.amount);
  const razorpayAmountPaise = capturedAmountPaise ?? recordedAmountPaise;
  const isDuplicateFinalState = payment.status === status;

  if (
    status === PaymentStatus.FAILED &&
    (payment.status === PaymentStatus.CAPTURED || payment.status === PaymentStatus.REFUNDED)
  ) {
    logger.info({ bookingId: payment.bookingId, orderId }, "Ignoring stale payment failure after capture");
    return payment;
  }

  if (
    status === PaymentStatus.CAPTURED &&
    (payment.status === PaymentStatus.REFUNDED || payment.booking.status === BookingStatus.REFUNDED)
  ) {
    logger.warn({ bookingId: payment.bookingId, orderId }, "Ignoring capture event for an already refunded booking");
    return payment;
  }

  if (status === PaymentStatus.CAPTURED) {
    if (recordedAmountPaise !== expectedAmountPaise || razorpayAmountPaise !== expectedAmountPaise) {
      const updatedPayment = await prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.FAILED,
          notes: {
            ...getPaymentNotes(payment),
            ...compactNotes(notes),
            amountMismatch: true,
            expectedAmountPaise,
            recordedAmountPaise,
            razorpayAmountPaise,
            flaggedAt: new Date().toISOString()
          } as Prisma.InputJsonValue
        },
        include: {
          booking: true
        }
      });

      logger.warn(
        {
          orderId,
          bookingId: payment.bookingId,
          expectedAmountPaise,
          recordedAmountPaise,
          razorpayAmountPaise
        },
        "Webhook payment amount mismatch"
      );

      await publishTrackingEvent({
        bookingId: payment.bookingId,
        bookingCode: payment.booking.code,
        status: "PAYMENT_AMOUNT_MISMATCH",
        message: "Payment amount did not match the expected gateway charge",
        paymentId: String(notes.paymentId ?? payment.id)
      });

      return updatedPayment;
    }
  }

  const updatedPayment = await prisma.payment.update({
    where: { id: payment.id },
    data: {
      status,
      notes: mergePaymentNotes(payment, notes)
    },
    include: {
      booking: true
    }
  });

  if (status === PaymentStatus.CAPTURED) {
    if (isCancelledBookingStatus(payment.booking.status)) {
      await flagPaymentCapturedAfterCancellation(payment, orderId, notes, !isDuplicateFinalState);
      return updatedPayment;
    }

    const shouldApplyCapturedSideEffects = payment.status !== PaymentStatus.CAPTURED || payment.booking.status !== BookingStatus.ACCEPTED;
    if (shouldApplyCapturedSideEffects) {
      const acceptedBooking = await prisma.booking.updateMany({
        data: { status: BookingStatus.ACCEPTED },
        where: {
          id: payment.bookingId,
          status: {
            notIn: [
              BookingStatus.CANCELLED,
              BookingStatus.CANCELLED_MANUAL,
              BookingStatus.CANCELLED_NO_SHOW,
              BookingStatus.REFUNDED
            ]
          }
        }
      });

      if (acceptedBooking.count === 0) {
        const currentBooking = await prisma.booking.findUnique({
          where: { id: payment.bookingId },
          select: { status: true }
        });
        if (currentBooking && isCancelledBookingStatus(currentBooking.status)) {
          await flagPaymentCapturedAfterCancellation(payment, orderId, notes, !isDuplicateFinalState);
        }
        return updatedPayment;
      }

      void recordBookingTimelineEvent({
        bookingId: payment.bookingId,
        status: BookingStatus.ACCEPTED,
        title: "Payment captured",
        description: "The payment webhook confirmed this booking."
      });

      void dispatchBookingAfterPayment(payment.bookingId).catch((error) => {
        logger.error(
          {
            error,
            bookingId: payment.bookingId,
            bookingCode: payment.booking.code,
            orderId
          },
          "Automatic dispatch failed after payment webhook confirmation"
        );
      });

      await publishTrackingEvent({
        bookingId: payment.bookingId,
        bookingCode: payment.booking.code,
        status: "PAYMENT_CAPTURED",
        message: "Payment captured by webhook",
        paymentId: String(notes.paymentId ?? payment.id)
      });
      await notifyUser(payment.booking.customerId, "Payment received", `Payment captured for booking ${payment.booking.code}.`, {
        bookingId: payment.bookingId,
        paymentId: String(notes.paymentId ?? payment.id)
      });
    }
  }

  if (status === PaymentStatus.FAILED) {
    if (isDuplicateFinalState) {
      return updatedPayment;
    }

    await publishTrackingEvent({
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      status: "PAYMENT_FAILED",
      message: "Payment failed",
      paymentId: String(notes.paymentId ?? payment.id)
    });
    await notifyUser(payment.booking.customerId, "Payment failed", `We could not confirm payment for booking ${payment.booking.code}.`, {
      bookingId: payment.bookingId,
      orderId
    });
  }

  if (status === PaymentStatus.REFUNDED) {
    const shouldApplyRefundSideEffects = payment.status !== PaymentStatus.REFUNDED || payment.booking.status !== BookingStatus.REFUNDED;
    if (shouldApplyRefundSideEffects) {
      await prisma.booking.update({
        where: { id: payment.bookingId },
        data: {
          status: BookingStatus.REFUNDED
        }
      });
      void recordBookingTimelineEvent({
        bookingId: payment.bookingId,
        status: BookingStatus.REFUNDED,
        title: "Payment refunded",
        description: "The payment was refunded by the provider."
      });
      await publishTrackingEvent({
        bookingId: payment.bookingId,
        bookingCode: payment.booking.code,
        status: "PAYMENT_REFUNDED",
        message: "Payment refunded",
        paymentId: String(notes.paymentId ?? payment.id)
      });
      await notifyUser(payment.booking.customerId, "Payment refunded", `Refund completed for booking ${payment.booking.code}.`, {
        bookingId: payment.bookingId,
        orderId
      });
    }
  }

  return updatedPayment;
}

async function updatePaymentForRefundWebhook(
  paymentId: string,
  status: PaymentStatus,
  notes: Record<string, unknown>
) {
  const payment = await findPaymentForRazorpayPaymentId(paymentId);

  if (!payment) {
    logger.warn({ paymentId, status }, "Refund webhook received for unknown payment");
    return null;
  }

  const refundId = typeof notes.refundId === "string" ? notes.refundId : null;
  const refundRecord = refundId
    ? await prisma.refund.findFirst({
        where: { bookingId: payment.bookingId, razorpayRefundId: refundId },
        select: { id: true, status: true }
      })
    : null;
  const internalRefundId = typeof notes.refundRecordId === "string" ? notes.refundRecordId : null;
  const providerAttemptId = typeof notes.refundAttemptId === "string" ? notes.refundAttemptId : null;
  const internalRefundRecord = internalRefundId
    ? await prisma.refund.findUnique({
        where: { id: internalRefundId },
        select: { id: true, status: true, razorpayRefundId: true, providerAttemptId: true }
      })
    : null;
  const internalRefundMatchesProviderId = Boolean(
    internalRefundRecord && refundId && internalRefundRecord.razorpayRefundId === refundId
  );
  const internalRefundMatchesAttempt = Boolean(
    internalRefundRecord &&
    internalRefundRecord.razorpayRefundId == null &&
    refundId &&
    providerAttemptId &&
    internalRefundRecord.providerAttemptId === providerAttemptId
  );
  const matchedRefund = refundRecord ?? (
    internalRefundMatchesProviderId || internalRefundMatchesAttempt ? internalRefundRecord : null
  );
  if (internalRefundRecord && !matchedRefund) {
    logger.warn(
      { paymentId, refundId, internalRefundId },
      "Ignoring refund webhook for a stale provider attempt"
    );
    return payment;
  }
  const refundFailed = status === PaymentStatus.FAILED;

  if (refundFailed && matchedRefund?.status === "processed") {
    logger.warn({ paymentId, refundId }, "Ignoring failed event for an already processed refund");
    return payment;
  }

  if (matchedRefund) {
    const settled = await settleRefundFromProvider(
      matchedRefund.id,
      !refundFailed,
      String(notes.refundStatus ?? "Refund failed at the payment provider"),
      { providerRefundId: refundId!, providerAttemptId }
    );
    if (settled === null) {
      logger.warn(
        { paymentId, refundId, internalRefundId: matchedRefund.id },
        "Ignoring refund webhook after its provider attempt became stale"
      );
      return payment;
    }
  }

  const processedRefunds = await prisma.refund.aggregate({
    where: { bookingId: payment.bookingId, status: "processed" },
    _sum: { amount: true }
  });
  const untrackedRefundAmount = matchedRefund
    ? 0
    : Math.max(0, Number(notes.refundAmount ?? 0) / 100);
  const refundedAmount = Number(processedRefunds._sum.amount ?? 0) + untrackedRefundAmount;
  const fullyRefunded = refundedAmount >= Number(payment.booking.totalAmount);

  const updatedPayment = await prisma.payment.update({
    where: { id: payment.id },
    data: {
      ...(status === PaymentStatus.REFUNDED && fullyRefunded
        ? { status: PaymentStatus.REFUNDED }
        : {}),
      notes: {
        ...getPaymentNotes(payment),
        ...compactNotes(notes)
      } as Prisma.InputJsonValue
    },
    include: {
      booking: true
    }
  });

  if (status === PaymentStatus.REFUNDED) {
    if (fullyRefunded) {
      await prisma.booking.update({
        where: { id: payment.bookingId },
        data: { status: BookingStatus.REFUNDED }
      });

      void recordBookingTimelineEvent({
        bookingId: payment.bookingId,
        status: BookingStatus.REFUNDED,
        title: "Payment refunded",
        description: "The full payment was refunded by the provider."
      });
    }

    await publishTrackingEvent({
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      status: fullyRefunded ? "PAYMENT_REFUNDED" : "PAYMENT_PARTIALLY_REFUNDED",
      message: fullyRefunded ? "Payment refunded" : "A partial payment refund was processed",
      paymentId
    });

    await notifyUser(
      payment.booking.customerId,
      fullyRefunded ? "Payment refunded" : "Partial refund processed",
      fullyRefunded
        ? `The payment for booking ${payment.booking.code} was refunded.`
        : `A partial refund for booking ${payment.booking.code} was processed.`,
      {
        bookingId: payment.bookingId,
        paymentId,
        fullyRefunded
      }
    );
  } else if (status === PaymentStatus.FAILED) {
    await publishTrackingEvent({
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      status: "REFUND_FAILED",
      message: "Refund failed",
      paymentId
    });

    await notifyUser(
      payment.booking.customerId,
      "Refund failed",
      `We could not complete a refund for booking ${payment.booking.code}.`,
      {
        bookingId: payment.bookingId,
        paymentId
      }
    );
  }

  return updatedPayment;
}

export async function handleRazorpayWebhook(
  rawBody: string,
  signature: string | undefined,
  body: RazorpayWebhookEvent
): Promise<{ ok: true }> {
  if (!signature) {
    throw AppError.unauthorized("Missing Razorpay webhook signature");
  }

  if (!verifyWebhookSignature(rawBody, signature)) {
    throw AppError.unauthorized("Invalid Razorpay webhook signature");
  }

  const deliveryKey = await claimWebhookDelivery(rawBody, signature);
  if (!deliveryKey) {
    logger.info({ event: body.event ?? "unknown" }, "Duplicate Razorpay webhook delivery ignored");
    return { ok: true };
  }

  try {
    return await processClaimedRazorpayWebhook(body);
  } catch (error) {
    try {
      await redis.del(deliveryKey);
    } catch (cleanupError) {
      logger.error({ error: cleanupError, event: body.event ?? "unknown" }, "Could not release failed webhook claim");
    }
    throw error;
  }
}

async function processClaimedRazorpayWebhook(body: RazorpayWebhookEvent): Promise<{ ok: true }> {
  const event = body.event ?? "unknown";
  const refundEntity = body.payload?.refund?.entity;
  const payoutEntity = body.payload?.payout?.entity;
  const paymentEntity = body.payload?.payment?.entity;
  const orderEntity = body.payload?.order?.entity;
  const orderId = paymentEntity?.order_id ?? orderEntity?.id;

  if (event.startsWith("payout.")) {
    await processPayoutWebhook(event, payoutEntity);
    return { ok: true };
  }

  if (event.startsWith("refund.")) {
    const refundPaymentId = refundEntity?.payment_id;
    if (!refundPaymentId) {
      logger.warn({ event }, "Refund webhook payload missing payment identifier");
      return { ok: true };
    }

    if (event === "refund.processed") {
      await updatePaymentForRefundWebhook(refundPaymentId, PaymentStatus.REFUNDED, {
        webhookEvent: event,
        refundId: refundEntity?.id,
        refundStatus: refundEntity?.status,
        paymentId: refundPaymentId,
        refundAmount: refundEntity?.amount,
        refundRecordId: refundEntity?.notes?.refundRecordId,
        refundAttemptId: refundEntity?.notes?.refundAttemptId
      });
    } else if (event === "refund.failed") {
      await updatePaymentForRefundWebhook(refundPaymentId, PaymentStatus.FAILED, {
        webhookEvent: event,
        refundId: refundEntity?.id,
        refundStatus: refundEntity?.status,
        paymentId: refundPaymentId,
        refundAmount: refundEntity?.amount,
        refundRecordId: refundEntity?.notes?.refundRecordId,
        refundAttemptId: refundEntity?.notes?.refundAttemptId
      });
    } else {
      logger.info({ event, refundPaymentId }, "Ignored refund lifecycle event");
    }

    return { ok: true };
  }

  if (!orderId) {
    logger.warn({ event }, "Webhook payload missing order identifier");
    return { ok: true };
  }

  if (event === "payment.captured" || event === "order.paid") {
    await updatePaymentForWebhook(orderId, PaymentStatus.CAPTURED, {
      webhookEvent: event,
      paymentId: paymentEntity?.id,
      paymentStatus: paymentEntity?.status
    }, paymentEntity?.amount);
  } else if (event === "payment.failed") {
    await updatePaymentForWebhook(orderId, PaymentStatus.FAILED, {
      webhookEvent: event,
      paymentId: paymentEntity?.id,
      paymentStatus: paymentEntity?.status
    });
  } else {
    logger.info({ event, orderId }, "Ignored webhook event");
  }

  return { ok: true };
}

async function processPayoutWebhook(
  event: string,
  entity: RazorpayPayoutEntity | undefined
): Promise<void> {
  const providerPayoutId = entity?.id;
  const referenceId = entity?.reference_id;
  const providerAttemptId = entity?.notes?.payoutAttemptId;
  const walletTransactionId = entity?.notes?.walletTransactionId;
  const status = event === "payout.processed"
    ? "processed"
    : event === "payout.failed"
      ? "failed"
      : event === "payout.reversed"
        ? "reversed"
        : null;

  if (!providerPayoutId || !status) {
    logger.info({ event, providerPayoutId }, "Ignored incomplete or unsupported payout webhook");
    return;
  }

  if (walletTransactionId || referenceId) {
    const transactionId = walletTransactionId ?? referenceId!;
    const settled = await settleWalletPayoutFromProvider({
      transactionId,
      providerPayoutId,
      providerAttemptId,
      status,
      failureReason: entity?.error_description ?? `Razorpay payout ${status}`
    });
    if (settled) {
      logger.info({ event, transactionId, providerPayoutId }, "Wallet payout settled from Razorpay webhook");
    }
  }

  // Wallet payout references are wallet transaction IDs. Booking payouts also
  // use the internal payout ID as reference_id, so only process a matching row.
  const payout = await prisma.payout.findFirst({
    where: {
      OR: [
        { razorpayPayoutId: providerPayoutId },
        ...(referenceId ? [{ id: referenceId }] : [])
      ]
    },
    select: { id: true, status: true, razorpayPayoutId: true, providerAttemptId: true }
  });
  if (!payout) return;
  if (payout.razorpayPayoutId && payout.razorpayPayoutId !== providerPayoutId) {
    logger.warn({ event, payoutId: payout.id, providerPayoutId }, "Ignored payout webhook for a stale provider payout");
    return;
  }
  if (providerAttemptId && payout.providerAttemptId !== providerAttemptId) {
    logger.warn({ event, payoutId: payout.id, providerAttemptId }, "Ignored payout webhook for a stale payout attempt");
    return;
  }
  if (!payout.razorpayPayoutId && !providerAttemptId) {
    logger.warn({ event, payoutId: payout.id }, "Ignored payout webhook without an identifiable active attempt");
    return;
  }

  const eligibleStatuses = status === "reversed"
    ? ["pending", "processing", "success"]
    : status === "processed"
      ? ["pending", "processing", "failed"]
      : ["pending", "processing"];
  const result = await prisma.payout.updateMany({
    where: {
      id: payout.id,
      status: { in: eligibleStatuses },
      ...(payout.providerAttemptId ? { providerAttemptId: payout.providerAttemptId } : {})
    },
    data: {
      status: status === "processed" ? "success" : "failed",
      razorpayPayoutId: providerPayoutId,
      failureReason: status === "processed" ? null : (entity?.error_description ?? `Razorpay payout ${status}`)
    }
  });
  if (result.count > 0) {
    logger.info({ event, payoutId: payout.id, providerPayoutId }, "Booking payout settled from Razorpay webhook");
  }
}
