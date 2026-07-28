import { BookingStatus, PaymentStatus, Prisma } from "@prisma/client";
import { createHmac } from "crypto";
import { env } from "../../config/env.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import {
  publishNotificationEvent,
  publishTrackingEvent
} from "../../lib/realtime.js";
import { dispatchBookingAfterPayment } from "../matching/matching.service.js";

type RazorpayWebhookEvent = {
  event?: string;
  payload?: {
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
  };
};

function verifyWebhookSignature(rawBody: string, signature: string): boolean {
  if (!env.RAZORPAY_WEBHOOK_SECRET) {
    throw new Error("Razorpay webhook secret is not configured");
  }

  const expected = createHmac("sha256", env.RAZORPAY_WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");

  return expected === signature;
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

async function updatePaymentForWebhook(
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

  const expectedAmountPaise = toPaise(payment.booking.totalAmount);
  const recordedAmountPaise = toPaise(payment.amount);
  const razorpayAmountPaise = capturedAmountPaise ?? recordedAmountPaise;

  if (status === PaymentStatus.CAPTURED) {
    if (recordedAmountPaise !== expectedAmountPaise || razorpayAmountPaise !== expectedAmountPaise) {
      const updatedPayment = await prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.FAILED,
          notes: {
            ...(payment.notes && typeof payment.notes === "object" ? (payment.notes as Record<string, unknown>) : {}),
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
        message: "Payment amount did not match the booking total",
        paymentId: String(notes.paymentId ?? payment.id)
      });

      return updatedPayment;
    }
  }

  const updatedPayment = await prisma.payment.update({
    where: { id: payment.id },
    data: {
      status,
      notes: {
        ...(payment.notes && typeof payment.notes === "object" ? (payment.notes as Record<string, unknown>) : {}),
        ...compactNotes(notes)
      } as Prisma.InputJsonValue
    },
    include: {
      booking: true
    }
  });

  if (status === PaymentStatus.CAPTURED) {
    await prisma.booking.update({
      where: { id: payment.bookingId },
      data: {
        status: BookingStatus.ACCEPTED
      }
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

  if (status === PaymentStatus.FAILED) {
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
    await prisma.booking.update({
      where: { id: payment.bookingId },
      data: {
        status: BookingStatus.REFUNDED
      }
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

  return updatedPayment;
}

export async function handleRazorpayWebhook(
  rawBody: string,
  signature: string | undefined,
  body: RazorpayWebhookEvent
): Promise<{ ok: true }> {
  if (!signature) {
    throw new Error("Missing Razorpay webhook signature");
  }

  if (!verifyWebhookSignature(rawBody, signature)) {
    throw new Error("Invalid Razorpay webhook signature");
  }

  const event = body.event ?? "unknown";
  const paymentEntity = body.payload?.payment?.entity;
  const orderEntity = body.payload?.order?.entity;
  const orderId = paymentEntity?.order_id ?? orderEntity?.id;

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
  } else if (event === "payment.refunded") {
    await updatePaymentForWebhook(orderId, PaymentStatus.REFUNDED, {
      webhookEvent: event,
      paymentId: paymentEntity?.id,
      paymentStatus: paymentEntity?.status
    });
  } else {
    logger.info({ event, orderId }, "Ignored webhook event");
  }

  return { ok: true };
}
