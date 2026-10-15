import { BookingStatus, PaymentStatus, Prisma } from "@prisma/client";
import Razorpay from "razorpay";
import { createHmac, timingSafeEqual } from "crypto";
import { env } from "../../config/env.js";
import { AppError } from "../../lib/app-error.js";
import { prisma } from "../../lib/prisma.js";
import { toPaise } from "../../lib/gst.js";
import { raiseOpsAlert } from "../ops/ops.service.js";
import { terminalBookingStatuses } from "./custom-quote.service.js";

function client(): Razorpay {
  if (!env.RAZORPAY_KEY_ID || !env.RAZORPAY_KEY_SECRET) throw new AppError(500, "Razorpay credentials are not configured");
  return new Razorpay({ key_id: env.RAZORPAY_KEY_ID, key_secret: env.RAZORPAY_KEY_SECRET });
}

function matchesSignature(orderId: string, paymentId: string, signature: string): boolean {
  if (!env.RAZORPAY_KEY_SECRET || !/^[a-f\d]{64}$/i.test(signature)) return false;
  const expected = createHmac("sha256", env.RAZORPAY_KEY_SECRET).update(`${orderId}|${paymentId}`).digest("hex");
  return timingSafeEqual(Buffer.from(expected, "hex"), Buffer.from(signature, "hex"));
}

async function raiseQuoteCaptureAfterRefundAlert(input: {
  bookingId: string;
  revisionId: string;
  paymentId: string;
  expectedAmountPaise: number;
  capturedAmountPaise: number;
}): Promise<void> {
  await raiseOpsAlert({
    type: "payment_mismatch",
    sourceId: `quote-capture-after-refund:${input.paymentId}`,
    bookingId: input.bookingId,
    severity: "critical",
    message: `A quote payment was captured after quote revision ${input.revisionId} was refunded. Review the provider transaction and refund eligibility.`,
    metadata: {
      title: "Quote payment captured after refund",
      bookingId: input.bookingId,
      quoteRevisionId: input.revisionId,
      paymentId: input.paymentId,
      expectedAmountPaise: input.expectedAmountPaise,
      capturedAmountPaise: input.capturedAmountPaise,
      retryAvailable: false
    }
  });
}

export async function createCustomQuotePaymentOrder(bookingId: string, customerId: string) {
  const revision = await prisma.customQuoteRevision.findFirst({
    where: { bookingId }, orderBy: { version: "desc" },
    include: { booking: { include: { customer: true } }, payments: { where: { status: PaymentStatus.PENDING }, orderBy: { createdAt: "desc" }, take: 1 } }
  });
  if (!revision) throw AppError.notFound("Quote not found");
  if (revision.booking.customerId !== customerId) throw AppError.forbidden("Not your booking");
  if (terminalBookingStatuses.includes(revision.booking.status)) {
    throw AppError.conflict("A quote cannot be paid for a closed booking");
  }
  const chargeableStatuses = ["PENDING", "PAYMENT_FAILED", "ORDER_CREATING", "PAYMENT_PENDING"];
  if (
    revision.status !== "ACCEPTED" ||
    revision.amount == null ||
    !chargeableStatuses.includes(revision.paymentStatus)
  ) {
    throw AppError.conflict("Only an accepted, unpaid quote can be charged");
  }
  const existing = revision.payments[0];
  if (existing?.providerRef) {
    return {
      keyId: env.RAZORPAY_KEY_ID!, orderId: existing.providerRef,
      amountPaise: toPaise(existing.amount), currency: existing.currency,
      bookingCode: revision.booking.code, customerName: revision.booking.customer.name,
      customerEmail: revision.booking.customer.email ?? "", customerPhone: revision.booking.customer.phone ?? ""
    };
  }

  const claimAt = new Date();
  const staleClaimBefore = new Date(claimAt.getTime() - 2 * 60 * 1000);
  const claim = await prisma.customQuoteRevision.updateMany({
    where: {
      id: revision.id,
      status: "ACCEPTED",
      OR: [
        { paymentStatus: { in: ["PENDING", "PAYMENT_FAILED"] } },
        {
          paymentStatus: "ORDER_CREATING",
          updatedAt: { lt: staleClaimBefore }
        }
      ]
    },
    data: { paymentStatus: "ORDER_CREATING", updatedAt: claimAt }
  });
  if (claim.count !== 1) throw AppError.conflict("Quote payment is already being prepared");

  try {
    const amountPaise = toPaise(revision.amount);
    const order = await client().orders.create({
      amount: amountPaise, currency: "INR", receipt: `quote-${revision.id}`,
      notes: { bookingId, quoteRevisionId: revision.id, quoteVersion: String(revision.version) }
    });
    await prisma.$transaction(async (tx) => {
      const finalizedClaim = await tx.customQuoteRevision.updateMany({
        where: {
          id: revision.id,
          paymentStatus: "ORDER_CREATING",
          updatedAt: claimAt
        },
        data: { paymentStatus: "PAYMENT_PENDING" }
      });
      if (finalizedClaim.count !== 1) {
        throw AppError.conflict("Quote payment preparation was taken over. Retry payment.");
      }
      await tx.payment.create({
        data: {
          bookingId, customQuoteRevisionId: revision.id, provider: "RAZORPAY", providerRef: order.id,
          amount: revision.amount!, currency: "INR", status: PaymentStatus.PENDING,
          notes: { paymentType: "CUSTOM_QUOTE", quoteVersion: revision.version } as Prisma.InputJsonValue
        }
      });
    });
    return {
      keyId: env.RAZORPAY_KEY_ID!, orderId: order.id, amountPaise, currency: "INR",
      bookingCode: revision.booking.code, customerName: revision.booking.customer.name,
      customerEmail: revision.booking.customer.email ?? "", customerPhone: revision.booking.customer.phone ?? ""
    };
  } catch (error) {
    await prisma.customQuoteRevision.updateMany({
      where: {
        id: revision.id,
        paymentStatus: "ORDER_CREATING",
        updatedAt: claimAt
      },
      data: { paymentStatus: "PENDING" }
    });
    throw error;
  }
}

export async function verifyCustomQuotePayment(input: {
  bookingId: string; customerId: string; orderId: string; paymentId: string; signature: string;
}) {
  const payment = await prisma.payment.findFirst({
    where: { bookingId: input.bookingId, providerRef: input.orderId, customQuoteRevisionId: { not: null } },
    include: { booking: true }
  });
  if (!payment) throw AppError.notFound("Quote payment not found");
  if (payment.booking.customerId !== input.customerId) throw AppError.forbidden("Not your booking");
  if (!matchesSignature(input.orderId, input.paymentId, input.signature)) throw AppError.badRequest("Invalid payment signature");
  const fetched = await client().payments.fetch(input.paymentId);
  if (fetched.order_id !== input.orderId || fetched.status !== "captured" || fetched.amount !== toPaise(payment.amount)) {
    throw AppError.conflict("Razorpay has not confirmed the expected quote payment");
  }
  await settleCustomQuotePayment(payment.id, PaymentStatus.CAPTURED, fetched.amount, { paymentId: input.paymentId, verifiedAt: new Date().toISOString() });
  return { bookingId: payment.bookingId, paymentId: input.paymentId, status: PaymentStatus.CAPTURED };
}

export async function settleCustomQuotePayment(
  paymentId: string, status: PaymentStatus, capturedAmountPaise?: number, notes: Record<string, unknown> = {}
) {
  const payment = await prisma.payment.findUnique({
    where: { id: paymentId }, include: { customQuoteRevision: true, booking: true }
  });
  if (!payment?.customQuoteRevisionId || !payment.customQuoteRevision) return null;
  const revision = payment.customQuoteRevision;
  if (status === PaymentStatus.CAPTURED) {
    const expectedPaise = toPaise(payment.amount);
    const confirmedAmountPaise = capturedAmountPaise ?? expectedPaise;
    const paymentNotes = payment.notes && typeof payment.notes === "object" && !Array.isArray(payment.notes)
      ? payment.notes as Record<string, unknown>
      : {};
    if (
      payment.status === PaymentStatus.CAPTURED &&
      paymentNotes.capturedAfterQuoteRefund === true &&
      (revision.paymentStatus === "REFUNDED" || revision.paymentStatus === "PARTIALLY_REFUNDED")
    ) {
      await raiseQuoteCaptureAfterRefundAlert({
        bookingId: payment.bookingId,
        revisionId: revision.id,
        paymentId,
        expectedAmountPaise: expectedPaise,
        capturedAmountPaise: confirmedAmountPaise
      });
      return { capturedAfterRefund: true, status: PaymentStatus.CAPTURED };
    }
    if (revision.paymentStatus === "PAID") {
      const duplicatePayment = await prisma.payment.updateMany({
        where: { id: paymentId, status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] } },
        data: {
          status: PaymentStatus.CAPTURED,
          notes: {
            ...paymentNotes,
            ...notes,
            duplicateQuoteCapture: true,
            expectedAmountPaise: expectedPaise,
            capturedAmountPaise: confirmedAmountPaise,
            capturedAt: new Date().toISOString()
          } as Prisma.InputJsonValue
        }
      });
      if (duplicatePayment.count === 0) {
        // The original payment was already captured; repeated verify/webhook
        // delivery is an idempotent no-op, not a second charge.
        return { duplicateCapture: false, mismatch: confirmedAmountPaise !== expectedPaise };
      }
      await raiseOpsAlert({
        type: "payment_mismatch",
        sourceId: `duplicate-quote-capture:${paymentId}`,
        bookingId: payment.bookingId,
        severity: "critical",
        message: `An additional payment capture was received for already-paid quote revision ${revision.id}. Review the provider transaction and refund eligibility.`,
        metadata: {
          title: "Duplicate custom quote payment capture",
          bookingId: payment.bookingId,
          quoteRevisionId: revision.id,
          paymentId,
          expectedAmountPaise: expectedPaise,
          actualCapturedAmountPaise: confirmedAmountPaise,
          retryAvailable: false
        }
      });
      return { duplicateCapture: true, mismatch: confirmedAmountPaise !== expectedPaise };
    }
    if (confirmedAmountPaise !== expectedPaise || revision.amount == null) {
      const mismatchRecorded = await prisma.$transaction(async (tx) => {
        const captured = await tx.payment.updateMany({
          where: {
            id: paymentId,
            status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] }
          },
          data: {
            status: PaymentStatus.CAPTURED,
            notes: {
              ...(payment.notes as object ?? {}),
              ...notes,
              amountMismatch: true,
              expectedAmountPaise: expectedPaise,
              capturedAmountPaise: confirmedAmountPaise,
              ...((revision.paymentStatus === "REFUNDED" || revision.paymentStatus === "PARTIALLY_REFUNDED")
                ? { capturedAfterQuoteRefund: true }
                : {}),
              capturedAt: new Date().toISOString()
            } as Prisma.InputJsonValue
          }
        });
        if (captured.count !== 1) return false;
        if (revision.paymentStatus === "REFUNDED" || revision.paymentStatus === "PARTIALLY_REFUNDED") {
          return true;
        }
        await tx.customQuoteRevision.updateMany({
          where: {
            id: revision.id,
            paymentStatus: { in: ["PENDING", "ORDER_CREATING", "PAYMENT_PENDING", "PAYMENT_FAILED"] }
          },
          data: { paymentStatus: "PAYMENT_FAILED" }
        });
        return true;
      });
      if (mismatchRecorded && (revision.paymentStatus === "REFUNDED" || revision.paymentStatus === "PARTIALLY_REFUNDED")) {
        await raiseQuoteCaptureAfterRefundAlert({
          bookingId: payment.bookingId,
          revisionId: revision.id,
          paymentId,
          expectedAmountPaise: expectedPaise,
          capturedAmountPaise: confirmedAmountPaise
        });
      } else if (mismatchRecorded) {
        await raiseOpsAlert({
          type: "payment_mismatch",
          sourceId: `quote-amount-mismatch:${paymentId}`,
          bookingId: payment.bookingId,
          severity: "critical",
          message: `A custom quote payment was captured for an unexpected amount on revision ${revision.id}. Review the captured payment and refund eligibility.`,
          metadata: {
            title: "Custom quote payment amount mismatch",
            bookingId: payment.bookingId,
            quoteRevisionId: revision.id,
            paymentId,
            expectedAmountPaise: expectedPaise,
            capturedAmountPaise: confirmedAmountPaise,
            retryAvailable: false
          }
        });
      }
      return { mismatch: true };
    }
    const settlement = await prisma.$transaction(async (tx) => {
      const lockedBookings = await tx.$queryRaw<Array<{ status: BookingStatus }>>`
        SELECT "status" FROM "Booking" WHERE "id" = ${payment.bookingId} FOR UPDATE
      `;
      const currentBookingStatus = lockedBookings[0]?.status ?? payment.booking.status;
      if (terminalBookingStatuses.includes(currentBookingStatus)) {
        const paymentCapture = await tx.payment.updateMany({
          where: { id: paymentId, status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] } },
          data: {
            status: PaymentStatus.CAPTURED,
            notes: {
              ...(payment.notes as object ?? {}),
              ...notes,
              capturedAfterBookingClosed: true,
              expectedAmountPaise: expectedPaise,
              capturedAmountPaise: confirmedAmountPaise,
              capturedAt: new Date().toISOString()
            } as Prisma.InputJsonValue
          }
        });
        return { capturedAfterClose: true, newlyCaptured: paymentCapture.count === 1 };
      }

      const paymentClaim = await tx.payment.updateMany({
        where: { id: paymentId, status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] } },
        data: { status: PaymentStatus.CAPTURED, notes: { ...(payment.notes as object ?? {}), ...notes, capturedAt: new Date().toISOString() } as Prisma.InputJsonValue }
      });
      if (paymentClaim.count === 0) return { capturedAfterClose: false, newlyCaptured: false };
      const quoteClaim = await tx.customQuoteRevision.updateMany({
        where: { id: revision.id, status: "ACCEPTED", paymentStatus: { in: ["PENDING", "ORDER_CREATING", "PAYMENT_PENDING", "PAYMENT_FAILED"] } },
        data: { paymentStatus: "PAID", paidAt: new Date() }
      });
      if (quoteClaim.count !== 1) {
        const currentRevision = await tx.customQuoteRevision.findUnique({
          where: { id: revision.id },
          select: { paymentStatus: true }
        });
        if (currentRevision?.paymentStatus === "REFUNDED" || currentRevision?.paymentStatus === "PARTIALLY_REFUNDED") {
          await tx.payment.update({
            where: { id: paymentId },
            data: {
              notes: {
                ...(payment.notes as object ?? {}),
                ...notes,
                capturedAfterQuoteRefund: true,
                expectedAmountPaise: expectedPaise,
                capturedAmountPaise: confirmedAmountPaise,
                capturedAt: new Date().toISOString()
              } as Prisma.InputJsonValue
            }
          });
          return { capturedAfterClose: false, capturedAfterRefund: true, newlyCaptured: true };
        }
        throw AppError.conflict("Quote payment no longer matches an accepted quote");
      }
      const amount = Number(revision.amount);
      const tax = Number(revision.taxAmount ?? 0);
      await tx.booking.update({
        where: { id: payment.bookingId },
        data: {
          subtotalAmount: { increment: amount },
          taxAmount: { increment: tax },
          totalAmount: { increment: amount }
        }
      });
      const invoice = await tx.invoice.findUnique({ where: { bookingId: payment.bookingId } });
      if (invoice) {
        const invoiceLines = Array.isArray(invoice.lineItems) ? [...invoice.lineItems as Array<Record<string, unknown>>] : [];
        if (!invoiceLines.some((line) => line.customQuoteRevisionId === revision.id)) {
          const quoteLines = Array.isArray(revision.itemized) ? revision.itemized as Array<Record<string, unknown>> : [];
          const quoteLineTotal = quoteLines.reduce((sum, line) => sum + Number(line.qty ?? 1) * Number(line.unitPrice ?? 0), 0);
          const quoteLineItems = quoteLines.map((line) => {
            const lineTotal = Number(line.qty ?? 1) * Number(line.unitPrice ?? 0);
            const lineTax = quoteLineTotal > 0 ? Math.round(tax * lineTotal / quoteLineTotal * 100) / 100 : 0;
            const lineBase = Math.round((lineTotal - lineTax) * 100) / 100;
            return {
              customQuoteRevisionId: revision.id,
              description: `Quote v${revision.version}: ${String(line.label ?? "Additional work")}`,
              sacCode: "PENDING",
              quantity: Number(line.qty ?? 1),
              unitPrice: Number(line.unitPrice ?? 0),
              basePrice: lineBase,
              gstRate: lineBase > 0 ? Math.round(lineTax / lineBase * 10000) / 100 : 0,
              gstAmount: lineTax,
              total: lineTotal
            };
          });
          await tx.invoice.update({
            where: { id: invoice.id },
            data: {
              lineItems: [...invoiceLines, ...quoteLineItems] as Prisma.InputJsonValue,
              subtotalAmount: { increment: amount },
              totalGstAmount: { increment: tax },
              grandTotal: { increment: amount }
            }
          });
        }
      }
      return { capturedAfterClose: false, newlyCaptured: true };
    });
    if ("capturedAfterRefund" in settlement && settlement.capturedAfterRefund) {
      if (settlement.newlyCaptured) {
        await raiseQuoteCaptureAfterRefundAlert({
          bookingId: payment.bookingId,
          revisionId: revision.id,
          paymentId,
          expectedAmountPaise: expectedPaise,
          capturedAmountPaise: confirmedAmountPaise
        });
      }
      return { capturedAfterRefund: true, status: PaymentStatus.CAPTURED };
    }
    if (settlement.capturedAfterClose) {
      if (settlement.newlyCaptured) {
        await raiseOpsAlert({
          type: "payment_mismatch",
          sourceId: `quote-capture-after-close:${paymentId}`,
          bookingId: payment.bookingId,
          severity: "critical",
          message: `A quote payment was captured after booking ${payment.bookingId} closed. Review refund eligibility.`,
          metadata: {
            title: "Quote payment captured after booking closure",
            bookingId: payment.bookingId,
            quoteRevisionId: revision.id,
            paymentId,
            expectedAmountPaise: expectedPaise,
            capturedAmountPaise: confirmedAmountPaise,
            retryAvailable: false
          }
        });
      }
      return { capturedAfterClose: true, status: PaymentStatus.CAPTURED };
    }
    return { status: PaymentStatus.CAPTURED };
  }
  if (status === PaymentStatus.FAILED) {
    await prisma.$transaction(async (tx) => {
      await tx.payment.updateMany({ where: { id: paymentId, status: PaymentStatus.PENDING }, data: { status, notes: { ...(payment.notes as object ?? {}), ...notes } as Prisma.InputJsonValue } });
      await tx.customQuoteRevision.updateMany({ where: { id: revision.id, paymentStatus: "PAYMENT_PENDING" }, data: { paymentStatus: "PAYMENT_FAILED" } });
    });
  }
  if (status === PaymentStatus.REFUNDED) {
    const refundAmountPaise = Number(notes.refundAmount ?? capturedAmountPaise ?? 0);
    if (!Number.isFinite(refundAmountPaise) || refundAmountPaise <= 0) {
      return { status: payment.status, ignored: true };
    }
    const refundEventId = typeof notes.refundId === "string"
      ? notes.refundId
      : typeof notes.refundRecordId === "string" ? notes.refundRecordId : null;
    const refundResult = await prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "Payment" WHERE "id" = ${paymentId} FOR UPDATE`;
      const lockedPayment = await tx.payment.findUnique({ where: { id: paymentId } });
      if (!lockedPayment) return { status, ignored: true };
      const paymentNotes = lockedPayment.notes && typeof lockedPayment.notes === "object" && !Array.isArray(lockedPayment.notes)
        ? lockedPayment.notes as Record<string, unknown>
        : {};
      const processedRefundIds = Array.isArray(paymentNotes.customQuoteRefundIds)
        ? paymentNotes.customQuoteRefundIds.filter((value): value is string => typeof value === "string")
        : [];
      if (refundEventId && processedRefundIds.includes(refundEventId)) {
        return { status, duplicate: true };
      }
      const priorRefundedPaise = Number(paymentNotes.customQuoteRefundedAmountPaise ?? 0);
      if (refundAmountPaise > toPaise(lockedPayment.amount) - priorRefundedPaise) {
        return { status, ignored: true };
      }
      const totalRefundedPaise = priorRefundedPaise + refundAmountPaise;
      const fullyRefunded = totalRefundedPaise >= toPaise(lockedPayment.amount);
      const paymentUpdate = await tx.payment.updateMany({
        where: {
          id: paymentId,
          status: { in: [PaymentStatus.PENDING, PaymentStatus.CAPTURED, PaymentStatus.REFUNDED] }
        },
        data: {
          ...(fullyRefunded ? { status: PaymentStatus.REFUNDED } : {}),
          notes: {
            ...paymentNotes,
            ...notes,
            customQuoteRefundedAmountPaise: totalRefundedPaise,
            customQuoteRefundIds: refundEventId
              ? [...processedRefundIds, refundEventId].slice(-32)
              : processedRefundIds,
            refundedAt: new Date().toISOString()
          } as Prisma.InputJsonValue
        }
      });
      if (paymentUpdate.count !== 1) return { status, ignored: true };
      const isExtraCapture =
        paymentNotes.amountMismatch === true ||
        paymentNotes.duplicateQuoteCapture === true ||
        paymentNotes.capturedAfterBookingClosed === true ||
        paymentNotes.capturedAfterQuoteRefund === true ||
        notes.amountMismatch === true ||
        notes.duplicateQuoteCapture === true ||
        notes.capturedAfterBookingClosed === true ||
        notes.capturedAfterQuoteRefund === true;
      if (isExtraCapture) {
        // Extra captures are tracked on their payment, but do not settle or
        // refund the quote revision's primary payment ledger.
        return { status, fullyRefunded, extraCaptureRefund: true };
      }
      const revisionUpdate = await tx.customQuoteRevision.updateMany({
        where: {
          id: revision.id,
          status: "ACCEPTED",
          paymentStatus: {
            in: ["PAID", "PAYMENT_PENDING", "PAYMENT_FAILED", "PARTIALLY_REFUNDED"]
          }
        },
        data: {
          paymentStatus: fullyRefunded ? "REFUNDED" : "PARTIALLY_REFUNDED"
        }
      });
      if (revisionUpdate.count !== 1) {
        throw AppError.conflict("The quote refund no longer matches an accepted quote");
      }
      return { status, fullyRefunded };
    });
    // Keep booking and invoice totals gross; the processed refund ledger records returned cash.
    return refundResult;
  }
  return { status };
}
