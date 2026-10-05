import { BookingStatus, PaymentStatus, Prisma } from "@prisma/client";
import { randomUUID } from "node:crypto";
import Razorpay from "razorpay";
import { AppError } from "../../lib/app-error.js";
import { env } from "../../config/env.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { maskWorkerFinancialFields } from "../../lib/mask-worker.js";

export class RefundNotFoundError extends Error {
  constructor(message = "Refund not found") {
    super(message);
    this.name = "RefundNotFoundError";
  }
}

export class RefundConflictError extends Error {
  constructor(message = "This refund cannot be retried") {
    super(message);
    this.name = "RefundConflictError";
  }
}

export class RefundProcessingError extends Error {
  constructor(
    readonly refundId: string,
    message: string,
    readonly providerRequestStarted: boolean
  ) {
    super(message);
    this.name = "RefundProcessingError";
  }
}

export type RefundStatus = "pending" | "processed" | "failed";

type RefundRecord = {
  id: string;
  bookingId: string;
  disputeId: string | null;
  amount: number;
  gatewayAmount: number | null;
  walletAmount: number;
  walletCreditedAt: Date | null;
  reason: string;
  status: string;
  razorpayRefundId: string | null;
  providerAttemptId: string | null;
  failureReason: string | null;
  createdAt: Date;
  updatedAt: Date;
};

type RefundListFilters = {
  status?: RefundStatus;
  workerId?: string;
  page?: number;
  pageSize?: number;
};

type RefundListItem = RefundRecord & {
  booking: {
    id: string;
    code: string;
    totalAmount: Prisma.Decimal;
    customer: {
      id: string;
      name: string;
      email: string | null;
      phone: string | null;
    };
    worker: Prisma.WorkerProfileGetPayload<{
      include: {
        user: true;
      };
    }> | null;
  };
};

// Keep provider setup lazy so importing refund helpers (for webhooks and tests)
// does not make the whole service fail when payment credentials are absent.
let razorpayClient: Razorpay | null = null;

function getRazorpayClient(): Razorpay {
  if (!razorpayClient) {
    razorpayClient = createRazorpayClient();
  }
  return razorpayClient;
}

function createRazorpayClient(): Razorpay {
  if (!env.RAZORPAY_KEY_ID || !env.RAZORPAY_KEY_SECRET) {
    throw new AppError(500, "Razorpay credentials are not configured");
  }

  return new Razorpay({
    key_id: env.RAZORPAY_KEY_ID,
    key_secret: env.RAZORPAY_KEY_SECRET
  });
}

function toPaise(amount: Prisma.Decimal | number | string): number {
  const value = typeof amount === "number" ? amount : Number(amount);
  return Math.max(0, Math.round(value * 100));
}

function toRupees(amount: Prisma.Decimal | number | string): number {
  return typeof amount === "number" ? amount : Number(amount);
}

function extractPaymentId(notes: Prisma.JsonValue | null | undefined): string | null {
  if (!notes || typeof notes !== "object" || Array.isArray(notes)) {
    return null;
  }

  const paymentId = (notes as Record<string, unknown>).paymentId;
  return typeof paymentId === "string" && paymentId.trim().length > 0 ? paymentId.trim() : null;
}

type RefundDbClient = Prisma.TransactionClient | typeof prisma;

async function fetchCapturedPayment(bookingId: string, db: RefundDbClient = prisma) {
  return db.payment.findFirst({
    where: {
      bookingId,
      provider: "RAZORPAY",
      status: PaymentStatus.CAPTURED
    },
    orderBy: {
      updatedAt: "desc"
    },
    select: {
      id: true,
      notes: true,
      providerRef: true,
      amount: true,
      booking: {
        select: {
          id: true,
          code: true,
          customerId: true,
          totalAmount: true
        }
      }
    }
  });
}

async function createRefundRecord(input: {
  bookingId: string;
  disputeId?: string | null;
  amount: Prisma.Decimal | number | string;
  gatewayAmount?: Prisma.Decimal | number | string | null;
  walletAmount?: Prisma.Decimal | number | string;
  walletCreditedAt?: Date | null;
  reason: string;
  status: RefundStatus;
  razorpayRefundId?: string | null;
  providerAttemptId?: string | null;
  failureReason?: string | null;
}, db: RefundDbClient = prisma): Promise<RefundRecord> {
  return db.refund.create({
    data: {
      bookingId: input.bookingId,
      disputeId: input.disputeId ?? null,
      amount: toRupees(input.amount),
      gatewayAmount: input.gatewayAmount == null ? null : toRupees(input.gatewayAmount),
      walletAmount: toRupees(input.walletAmount ?? 0),
      walletCreditedAt: input.walletCreditedAt ?? null,
      reason: input.reason,
      status: input.status,
      razorpayRefundId: input.razorpayRefundId ?? null,
      providerAttemptId: input.providerAttemptId ?? null,
      failureReason: input.failureReason ?? null
    }
  });
}

async function attemptRazorpayRefund(
  payment: NonNullable<Awaited<ReturnType<typeof fetchCapturedPayment>>>,
  refundId: string,
  providerAttemptId: string,
  amount: Prisma.Decimal | number | string,
  reason: string
): Promise<{
  ok: boolean;
  razorpayRefundId?: string;
  failureReason?: string;
  paymentId?: string;
  definitivelyRejected?: boolean;
}> {
  const paymentId = extractPaymentId(payment.notes);
  if (!paymentId) {
    return {
      ok: false,
      failureReason: "The captured payment does not include a Razorpay payment_id",
      definitivelyRejected: true
    };
  }

  const amountPaise = toPaise(amount);
  if (amountPaise <= 0) {
    return {
      ok: false,
      failureReason: "Refund amount must be greater than zero",
      definitivelyRejected: true
    };
  }

  const capturedAmountPaise = toPaise(payment.amount);
  if (Number.isFinite(capturedAmountPaise) && amountPaise > capturedAmountPaise) {
    return {
      ok: false,
      paymentId,
      failureReason: "Refund amount exceeds the amount captured by Razorpay",
      definitivelyRejected: true
    };
  }

  try {
    const refund = await getRazorpayClient().payments.refund(paymentId, {
      amount: amountPaise,
      notes: {
        reason,
        refundRecordId: refundId,
        refundAttemptId: providerAttemptId
      }
    });

    const razorpayRefundId = typeof refund.id === "string" ? refund.id : "";
    if (!razorpayRefundId) {
      return {
        ok: false,
        paymentId,
        failureReason: "Razorpay accepted the refund request but returned no refund ID"
      };
    }

    return {
      ok: true,
      razorpayRefundId,
      paymentId
    };
  } catch (error) {
    const errorRecord = typeof error === "object" && error !== null
      ? error as Record<string, unknown>
      : {};
    const nestedError = typeof errorRecord.error === "object" && errorRecord.error !== null
      ? errorRecord.error as Record<string, unknown>
      : {};
    const statusCode = Number(errorRecord.statusCode ?? errorRecord.status ?? nestedError.statusCode);
    const definitivelyRejected = statusCode >= 400 && statusCode < 500 &&
      ![408, 409, 425, 429].includes(statusCode);
    return {
      ok: false,
      paymentId,
      failureReason: error instanceof Error ? error.message : "Failed to create Razorpay refund",
      definitivelyRejected
    };
  }
}

async function calculateRefundAllocation(
  bookingId: string,
  amount: Prisma.Decimal | number | string,
  excludeRefundId?: string,
  db: RefundDbClient = prisma
) {
  const payment = await fetchCapturedPayment(bookingId, db);
  if (!payment) {
    return { payment: null, gatewayAmount: 0, walletAmount: 0 };
  }

  const priorRefunds = await db.refund.findMany({
    where: {
      bookingId,
      status: { in: ["pending", "processed"] },
      ...(excludeRefundId ? { id: { not: excludeRefundId } } : {})
    },
    select: { amount: true, gatewayAmount: true, walletAmount: true }
  });
  const rows = (priorRefunds ?? []) as Array<{
    amount: Prisma.Decimal | number;
    gatewayAmount: Prisma.Decimal | number | null;
    walletAmount: Prisma.Decimal | number | null;
  }>;
  const requestedPaise = toPaise(amount);
  const refundedTotalPaise = rows.reduce((sum, refund) => sum + toPaise(refund.amount), 0);
  const remainingTotalPaise = Math.max(0, toPaise(payment.booking.totalAmount) - refundedTotalPaise);
  if (requestedPaise <= 0 || requestedPaise > remainingTotalPaise) {
    throw AppError.conflict("Refund amount exceeds the remaining refundable booking balance");
  }

  const refundedGatewayPaise = rows.reduce(
    (sum, refund) => sum + toPaise(refund.gatewayAmount ?? refund.amount),
    0
  );
  const refundedWalletPaise = rows.reduce((sum, refund) => sum + toPaise(refund.walletAmount ?? 0), 0);
  const gatewayRemainingPaise = Math.max(0, toPaise(payment.amount) - refundedGatewayPaise);
  const walletDeductAmountPaise = (() => {
    if (!payment.notes || typeof payment.notes !== "object" || Array.isArray(payment.notes)) {
      return Math.max(0, toPaise(payment.booking.totalAmount) - toPaise(payment.amount));
    }
    const storedAmount = (payment.notes as Record<string, unknown>).walletDeductAmountPaise;
    return typeof storedAmount === "number"
      ? Math.max(0, Math.round(storedAmount))
      : Math.max(0, toPaise(payment.booking.totalAmount) - toPaise(payment.amount));
  })();
  const walletRemainingPaise = Math.max(0, walletDeductAmountPaise - refundedWalletPaise);
  const gatewayAmountPaise = Math.min(requestedPaise, gatewayRemainingPaise);
  const walletAmountPaise = requestedPaise - gatewayAmountPaise;

  if (walletAmountPaise > walletRemainingPaise) {
    throw AppError.conflict("Refund amount exceeds the remaining gateway and wallet contributions");
  }

  return {
    payment,
    gatewayAmount: gatewayAmountPaise / 100,
    walletAmount: walletAmountPaise / 100
  };
}

export async function settleRefundFromProvider(
  refundId: string,
  succeeded: boolean,
  failureReason?: string,
  providerEvent?: { providerRefundId: string; providerAttemptId: string | null }
) {
  return prisma.$transaction(async (tx) => {
    let refund = await tx.refund.findUnique({
      where: { id: refundId },
      include: { booking: { select: { customerId: true } } }
    });
    if (!refund) return null;
    if (providerEvent) {
      await tx.$queryRaw<Array<{ id: string }>>`SELECT "id" FROM "Booking" WHERE "id" = ${refund.bookingId} FOR UPDATE`;
      await tx.$queryRaw<Array<{ id: string }>>`SELECT "id" FROM "Refund" WHERE "id" = ${refundId} FOR UPDATE`;
      refund = await tx.refund.findUnique({
        where: { id: refundId },
        include: { booking: { select: { customerId: true } } }
      });
      if (!refund) return null;

      const refundIdMatches = refund.razorpayRefundId === providerEvent.providerRefundId;
      const attemptMatches = providerEvent.providerAttemptId !== null &&
        refund.providerAttemptId === providerEvent.providerAttemptId;
      if (!refundIdMatches && !attemptMatches) return null;
    }

    if (!succeeded) {
      if (refund.status === "processed") return refund;
      const failedRefund = await tx.refund.update({
        where: { id: refund.id },
        data: { status: "failed", failureReason: failureReason ?? "Refund failed at the payment provider" }
      });
      if (refund.disputeId) {
        await tx.dispute.updateMany({
          where: { id: refund.disputeId, status: "refund_pending" },
          data: { status: "under_review", resolvedAt: null }
        });
      }
      return failedRefund;
    }

    if (refund.walletAmount > 0 && !refund.walletCreditedAt) {
      const creditedAt = new Date();
      const claim = await tx.refund.updateMany({
        where: { id: refund.id, walletCreditedAt: null },
        data: { walletCreditedAt: creditedAt, status: "processed", failureReason: null }
      });
      if (claim.count === 1) {
        const customer = await tx.user.update({
          where: { id: refund.booking.customerId },
          data: { walletBalance: { increment: refund.walletAmount } },
          select: { walletBalance: true }
        });
        await tx.walletTransaction.create({
          data: {
            userId: refund.booking.customerId,
            type: "WALLET_CREDIT",
            amount: refund.walletAmount,
            referenceType: "BOOKING_REFUND",
            referenceId: refund.id,
            balanceAfter: customer.walletBalance,
            metadata: { reason: refund.reason, gatewayRefundId: refund.razorpayRefundId }
          }
        });
      }
    } else {
      await tx.refund.update({
        where: { id: refund.id },
        data: { status: "processed", failureReason: null }
      });
    }

    if (refund.disputeId) {
      await tx.dispute.updateMany({
        where: { id: refund.disputeId, status: { in: ["refund_pending", "under_review"] } },
        data: { status: "resolved_refund", resolvedAt: new Date() }
      });
    }

    const [processedRefunds, booking] = await Promise.all([
      tx.refund.aggregate({
        where: { bookingId: refund.bookingId, status: "processed" },
        _sum: { amount: true }
      }),
      tx.booking.findUnique({
        where: { id: refund.bookingId },
        select: { totalAmount: true }
      })
    ]);
    if (booking && toPaise(processedRefunds._sum.amount ?? 0) >= toPaise(booking.totalAmount)) {
      await tx.booking.update({
        where: { id: refund.bookingId },
        data: { status: BookingStatus.REFUNDED }
      });
      await tx.payment.updateMany({
        where: { bookingId: refund.bookingId },
        data: { status: PaymentStatus.REFUNDED }
      });
    }

    return tx.refund.findUnique({ where: { id: refund.id } });
  });
}

export async function processRefund(
  bookingId: string,
  amount: Prisma.Decimal | number | string,
  reason: string,
  disputeId?: string | null
): Promise<RefundRecord> {
  const reservation = await prisma.$transaction(async (tx) => {
    // Serialize refund balance checks and pending-reservation creation per booking.
    await tx.$queryRaw<Array<{ id: string }>>`SELECT "id" FROM "Booking" WHERE "id" = ${bookingId} FOR UPDATE`;
    const booking = await tx.booking.findUnique({
      where: { id: bookingId },
      select: { id: true, code: true, totalAmount: true }
    });
    if (!booking) {
      throw AppError.notFound("Booking not found for refund processing");
    }

    const allocation = await calculateRefundAllocation(booking.id, amount, undefined, tx);
    const providerAttemptId = allocation.payment && allocation.gatewayAmount > 0
      ? randomUUID()
      : null;
    const refund = await createRefundRecord({
      bookingId: booking.id,
      disputeId,
      amount: toPaise(amount) / 100,
      reason,
      gatewayAmount: allocation.gatewayAmount,
      walletAmount: allocation.walletAmount,
      status: "pending",
      providerAttemptId
    }, tx);
    return { booking, allocation, refund };
  });
  const { booking, allocation, refund } = reservation;
  let providerRequestStarted = false;

  try {
    if (allocation.gatewayAmount === 0 && allocation.walletAmount > 0) {
      await settleRefundFromProvider(refund.id, true);
    } else if (allocation.payment) {
      const providerAttemptId = refund.providerAttemptId;
      if (!providerAttemptId) {
        throw new Error("Refund provider attempt was not initialized");
      }
      providerRequestStarted = true;
      const result = await attemptRazorpayRefund(
        allocation.payment,
        refund.id,
        providerAttemptId,
        allocation.gatewayAmount,
        reason
      );
      const updated = await prisma.refund.updateMany({
        where: { id: refund.id, status: "pending" },
        data: result.ok
          ? { razorpayRefundId: result.razorpayRefundId ?? null }
          : result.definitivelyRejected
            ? { status: "failed", failureReason: result.failureReason ?? null }
            : { failureReason: result.failureReason ?? "Provider outcome is uncertain; reconciliation is required" }
      });
      if (result.ok && updated.count === 0) {
        await prisma.refund.updateMany({
          where: { id: refund.id, razorpayRefundId: null },
          data: { razorpayRefundId: result.razorpayRefundId ?? null }
        });
      }
    } else {
      await prisma.refund.updateMany({
        where: { id: refund.id, status: "pending" },
        data: { status: "failed", failureReason: "No captured Razorpay payment was found for this booking" }
      });
    }
  } catch (error) {
    const failureReason = error instanceof Error ? error.message : "Failed to persist refund processing result";
    try {
      await prisma.refund.updateMany({
        where: { id: refund.id, status: "pending" },
        data: providerRequestStarted
          ? { failureReason: `Provider outcome requires reconciliation: ${failureReason}` }
          : { status: "failed", failureReason }
      });
    } catch (persistenceError) {
      logger.error(
        { refundId: refund.id, error: persistenceError },
        "Failed to record refund processing failure"
      );
    }
    if (providerRequestStarted) {
      throw new RefundProcessingError(refund.id, failureReason, true);
    }
    throw error;
  }

  const recordedRefund = await prisma.refund.findUnique({ where: { id: refund.id } }) as RefundRecord;

  logger.info(
    {
      bookingId: booking.id,
      bookingCode: booking.code,
      refundId: refund.id,
      status: recordedRefund.status,
      razorpayRefundId: recordedRefund.razorpayRefundId,
      failureReason: recordedRefund.failureReason
    },
    "Refund attempt recorded"
  );

  return recordedRefund;
}

export async function retryRefund(refundId: string): Promise<RefundRecord> {
  const existing = await prisma.refund.findUnique({
    where: { id: refundId },
    select: {
      id: true,
      bookingId: true,
      amount: true,
      gatewayAmount: true,
      walletAmount: true,
      reason: true,
      status: true
    }
  });

  if (!existing) {
    throw new RefundNotFoundError();
  }

  if (existing.status !== "failed") {
    throw new RefundConflictError("Only failed refunds can be retried");
  }

  const retry = await prisma.$transaction(async (tx) => {
    await tx.$queryRaw<Array<{ id: string }>>`SELECT "id" FROM "Booking" WHERE "id" = ${existing.bookingId} FOR UPDATE`;
    const allocation = await calculateRefundAllocation(existing.bookingId, existing.amount, existing.id, tx);
    const providerAttemptId = allocation.payment && allocation.gatewayAmount > 0
      ? randomUUID()
      : null;
    const retryClaim = await tx.refund.updateMany({
      where: { id: refundId, status: "failed" },
      data: {
        status: "pending",
        gatewayAmount: allocation.gatewayAmount,
        walletAmount: allocation.walletAmount,
        failureReason: null,
        razorpayRefundId: null,
        providerAttemptId
      }
    });
    if (retryClaim.count !== 1) {
      throw new RefundConflictError("This refund is already being retried");
    }
    return { allocation, providerAttemptId };
  });
  const { allocation, providerAttemptId } = retry;
  const gatewayAmount = allocation.gatewayAmount;
  const walletAmount = allocation.walletAmount;

  if (gatewayAmount === 0 && walletAmount > 0) {
    await settleRefundFromProvider(refundId, true);
    const settledRefund = await prisma.refund.findUnique({ where: { id: refundId } });
    if (!settledRefund) throw new RefundNotFoundError();
    return settledRefund;
  }

  if (!allocation.payment) {
    await prisma.refund.updateMany({
      where: { id: refundId, status: "pending" },
      data: { status: "failed", failureReason: "No captured Razorpay payment was found for this booking" }
    });
    const failedRefund = await prisma.refund.findUnique({ where: { id: refundId } });
    if (!failedRefund) throw new RefundNotFoundError();
    return failedRefund;
  }

  if (!providerAttemptId) {
    throw new RefundConflictError("This refund has no active provider attempt");
  }
  const result = await attemptRazorpayRefund(
    allocation.payment,
    refundId,
    providerAttemptId,
    gatewayAmount,
    existing.reason
  );

  const retryUpdate = await prisma.refund.updateMany({
    where: { id: refundId, status: "pending" },
    data: result.ok
      ? { razorpayRefundId: result.razorpayRefundId ?? null }
      : result.definitivelyRejected
        ? { status: "failed", failureReason: result.failureReason ?? null }
        : { failureReason: result.failureReason ?? "Provider outcome is uncertain; reconciliation is required" }
  });
  if (result.ok && retryUpdate.count === 0) {
    await prisma.refund.updateMany({
      where: { id: refundId, razorpayRefundId: null },
      data: { razorpayRefundId: result.razorpayRefundId ?? null }
    });
  }
  const updated = await prisma.refund.findUnique({ where: { id: refundId } }) as RefundRecord;

  logger.info(
    {
      refundId: updated.id,
      bookingId: updated.bookingId,
      status: updated.status,
      razorpayRefundId: updated.razorpayRefundId ?? null,
      failureReason: updated.failureReason ?? null
    },
    "Refund retry completed"
  );

  return updated;
}

export async function getAllRefunds(filters: RefundListFilters = {}): Promise<{
  items: RefundListItem[];
  total: number;
  page: number;
  pageSize: number;
}> {
  const page = filters.page ?? 1;
  const pageSize = filters.pageSize ?? 20;
  const where: Prisma.RefundWhereInput = {
    ...(filters.status ? { status: filters.status } : {}),
    ...(filters.workerId
      ? {
          booking: {
            workerId: filters.workerId
          }
        }
      : {})
  };

  const [items, total] = await Promise.all([
    prisma.refund.findMany({
      where,
      orderBy: [{ createdAt: "desc" }],
      take: pageSize,
      skip: (page - 1) * pageSize,
      select: {
        id: true,
        bookingId: true,
        disputeId: true,
        amount: true,
        gatewayAmount: true,
        walletAmount: true,
        walletCreditedAt: true,
        reason: true,
        status: true,
        razorpayRefundId: true,
        failureReason: true,
        createdAt: true,
        updatedAt: true,
        booking: {
          select: {
            id: true,
            code: true,
            totalAmount: true,
            customer: {
              select: {
                id: true,
                name: true,
                email: true,
                phone: true
              }
            },
            worker: {
              include: {
                user: true
              }
            }
          }
        }
      }
    }),
    prisma.refund.count({ where })
  ]);

  return {
    // Mask sensitive worker financial fields before sending to the client.
    // The worker's real data is untouched in the DB and available for any
    // internal operations (e.g. payout processing).
    items: items.map((item: any) => {
      if (!item.booking.worker) return item;
      return {
        ...item,
        booking: {
          ...item.booking,
          worker: maskWorkerFinancialFields(item.booking.worker)
        }
      };
    }) as RefundListItem[],
    total,
    page,
    pageSize
  };
}

export async function listRefunds(filters: RefundListFilters = {}): Promise<{
  items: RefundListItem[];
  total: number;
  page: number;
  pageSize: number;
}> {
  return getAllRefunds({
    ...filters,
    status: filters.status ?? "failed"
  });
}

export async function bulkRetryFailedRefunds(): Promise<{ attempted: number; succeeded: number; failed: number }> {
  const failedRefunds = await prisma.refund.findMany({
    where: { status: "failed" },
    orderBy: { createdAt: "asc" },
    take: 50
  });

  let succeeded = 0;
  let failed = 0;

  for (const refund of failedRefunds) {
    try {
      await retryRefund(refund.id);
      const result = await prisma.refund.findUnique({ where: { id: refund.id }, select: { status: true } });
      // A provider refund is accepted asynchronously; its webhook will move
      // it from pending to processed after Razorpay confirms settlement.
      if (result?.status === "pending" || result?.status === "processed") {
        succeeded++;
      } else {
        failed++;
      }
    } catch {
      failed++;
    }
  }

  return { attempted: failedRefunds.length, succeeded, failed };
}

export async function exportRefundsCsv(filters: RefundListFilters = {}): Promise<string> {
  const where: Prisma.RefundWhereInput = {
    ...(filters.status ? { status: filters.status } : {})
  };

  const items = await prisma.refund.findMany({
    where,
    include: {
      booking: {
        include: {
          customer: { select: { id: true, name: true, email: true, phone: true } },
          worker: { include: { user: true } }
        }
      }
    },
    orderBy: [{ createdAt: "desc" }],
    take: 5000
  });

  const header = ["ID", "Booking Code", "Customer Name", "Amount (Rs.)", "Reason", "Status", "Failure Reason", "Created At"];
  const rows = items.map((r) => {
    const amount = Number(r.amount ?? 0).toFixed(2);
    const reason = (r.reason ?? "").replace(/"/g, "'");
    const failureReason = (r.failureReason ?? "").replace(/"/g, "'");
    const customerName = (r.booking?.customer?.name ?? "Unknown").replace(/"/g, "'");
    return [r.id, r.booking?.code ?? "", customerName, amount, `"${reason}"`, r.status, `"${failureReason}"`, r.createdAt.toISOString()].join(",");
  });

  return [header.join(","), ...rows].join("\n");
}
