import { PaymentStatus, Prisma } from "@prisma/client";
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

export type RefundStatus = "pending" | "processed" | "failed";

type RefundRecord = {
  id: string;
  bookingId: string;
  disputeId: string | null;
  amount: number;
  reason: string;
  status: string;
  razorpayRefundId: string | null;
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

const razorpay = createRazorpayClient();

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

async function fetchCapturedPayment(bookingId: string) {
  return prisma.payment.findFirst({
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
      booking: {
        select: {
          id: true,
          code: true
        }
      }
    }
  });
}

async function createRefundRecord(input: {
  bookingId: string;
  disputeId?: string | null;
  amount: Prisma.Decimal | number | string;
  reason: string;
  status: RefundStatus;
  razorpayRefundId?: string | null;
  failureReason?: string | null;
}): Promise<RefundRecord> {
  return prisma.refund.create({
    data: {
      bookingId: input.bookingId,
      disputeId: input.disputeId ?? null,
      amount: toRupees(input.amount),
      reason: input.reason,
      status: input.status,
      razorpayRefundId: input.razorpayRefundId ?? null,
      failureReason: input.failureReason ?? null
    }
  });
}

async function attemptRazorpayRefund(
  bookingId: string,
  amount: Prisma.Decimal | number | string,
  reason: string
): Promise<{
  ok: boolean;
  razorpayRefundId?: string;
  failureReason?: string;
  paymentId?: string;
}> {
  const payment = await fetchCapturedPayment(bookingId);
  if (!payment) {
    return {
      ok: false,
      failureReason: "No captured Razorpay payment was found for this booking"
    };
  }

  const paymentId = extractPaymentId(payment.notes);
  if (!paymentId) {
    return {
      ok: false,
      failureReason: "The captured payment does not include a Razorpay payment_id"
    };
  }

  const amountPaise = toPaise(amount);
  if (amountPaise <= 0) {
    return {
      ok: false,
      failureReason: "Refund amount must be greater than zero"
    };
  }

  try {
    const refund = await razorpay.payments.refund(paymentId, {
      amount: amountPaise,
      notes: {
        reason
      }
    });

    return {
      ok: true,
      razorpayRefundId: String(refund.id ?? ""),
      paymentId
    };
  } catch (error) {
    return {
      ok: false,
      paymentId,
      failureReason: error instanceof Error ? error.message : "Failed to create Razorpay refund"
    };
  }
}

export async function processRefund(
  bookingId: string,
  amount: Prisma.Decimal | number | string,
  reason: string
): Promise<RefundRecord> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      code: true
    }
  });

  if (!booking) {
    throw AppError.notFound("Booking not found for refund processing");
  }

  const result = await attemptRazorpayRefund(bookingId, amount, reason);
  const status: RefundStatus = result.ok ? "processed" : "failed";

  const refund = await createRefundRecord({
    bookingId: booking.id,
    amount,
    reason,
    status,
    razorpayRefundId: result.ok ? result.razorpayRefundId ?? null : null,
    failureReason: result.ok ? null : result.failureReason ?? null
  });

  logger.info(
    {
      bookingId: booking.id,
      bookingCode: booking.code,
      refundId: refund.id,
      status,
      razorpayRefundId: result.razorpayRefundId ?? null,
      failureReason: result.failureReason ?? null
    },
    "Refund attempt recorded"
  );

  return refund;
}

export async function retryRefund(refundId: string): Promise<RefundRecord> {
  const existing = await prisma.refund.findUnique({
    where: { id: refundId },
    select: {
      id: true,
      bookingId: true,
      amount: true,
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

  await prisma.refund.update({
    where: { id: refundId },
    data: {
      status: "pending",
      failureReason: null
    }
  });

  const result = await attemptRazorpayRefund(existing.bookingId, existing.amount, existing.reason);
  const nextStatus: RefundStatus = result.ok ? "processed" : "failed";

  const updated = await prisma.refund.update({
    where: { id: refundId },
    data: {
      status: nextStatus,
      razorpayRefundId: result.ok ? result.razorpayRefundId ?? null : null,
      failureReason: result.ok ? null : result.failureReason ?? null
    }
  });

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
      if (result?.status === "processed") {
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
    const amount = (Number(r.amount ?? 0) / 100).toFixed(2);
    const reason = (r.reason ?? "").replace(/"/g, "'");
    const failureReason = (r.failureReason ?? "").replace(/"/g, "'");
    const customerName = (r.booking?.customer?.name ?? "Unknown").replace(/"/g, "'");
    return [r.id, r.booking?.code ?? "", customerName, amount, `"${reason}"`, r.status, `"${failureReason}"`, r.createdAt.toISOString()].join(",");
  });

  return [header.join(","), ...rows].join("\n");
}
