import { Prisma } from "@prisma/client";
import { randomUUID } from "crypto";
import { env } from "../../config/env.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { maskWorkerFinancialFields } from "../../lib/mask-worker.js";
import { AppError } from "../../lib/app-error.js";

type PayoutStatus = "pending" | "processing" | "success" | "failed";

type PayoutFilters = {
  status?: PayoutStatus;
  workerId?: string;
  page?: number;
  limit?: number;
};

type PayoutRecordWithBooking = Prisma.PayoutGetPayload<{
  include: {
    booking: {
      include: {
        worker: {
          include: {
            user: true;
          };
        };
      };
    };
  };
}>;

type RazorpayPayoutResponse = {
  id: string;
  status?: string;
  fund_account_id?: string;
  amount?: number;
  currency?: string;
  mode?: string;
  purpose?: string;
};

type PayoutAttemptContext = {
  payout: PayoutRecordWithBooking;
  bookingCode: string;
  workerName: string;
  mode: "UPI" | "IMPS";
  fundAccount: Record<string, unknown>;
  amountPaise: number;
};

function toNumber(value: Prisma.Decimal | number | string): number {
  return typeof value === "number" ? value : Number(value);
}

function roundToTwo(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export function getCommissionPercent(): number {
  return env.PLATFORM_COMMISSION_PERCENT ?? 20;
}

function getRazorpayAuthHeader(): string {
  if (!env.RAZORPAY_KEY_ID || !env.RAZORPAY_KEY_SECRET) {
    throw new AppError(500, "Razorpay credentials are not configured");
  }

  return `Basic ${Buffer.from(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`).toString("base64")}`;
}

function getRazorpayAccountNumber(): string {
  if (!env.RAZORPAY_ACCOUNT_NUMBER || env.RAZORPAY_ACCOUNT_NUMBER.trim().length === 0) {
    throw new AppError(500, "RAZORPAY_ACCOUNT_NUMBER is not configured");
  }

  return env.RAZORPAY_ACCOUNT_NUMBER.trim();
}

function extractFailureReason(payload: unknown, fallback: string): string {
  if (payload && typeof payload === "object") {
    const maybeError = payload as {
      description?: unknown;
      reason?: unknown;
      error?: {
        description?: unknown;
        reason?: unknown;
        field?: unknown;
      };
      message?: unknown;
    };

    const description =
      (typeof maybeError.description === "string" && maybeError.description) ||
      (typeof maybeError.message === "string" && maybeError.message) ||
      (typeof maybeError.error?.description === "string" && maybeError.error.description) ||
      null;
    const reason =
      (typeof maybeError.reason === "string" && maybeError.reason) ||
      (typeof maybeError.error?.reason === "string" && maybeError.error.reason) ||
      null;
    const field = typeof maybeError.error?.field === "string" ? maybeError.error.field : null;

    return [description, reason, field].filter(Boolean).join(" | ") || fallback;
  }

  return fallback;
}

async function getPayoutByBookingId(bookingId: string) {
  return prisma.payout.findUnique({
    where: { bookingId },
    include: {
      booking: {
        include: {
          worker: {
            include: {
              user: true
            }
          }
        }
      }
    }
  });
}

async function getPayoutById(payoutId: string) {
  return prisma.payout.findUnique({
    where: { id: payoutId },
    include: {
      booking: {
        include: {
          worker: {
            include: {
              user: true
            }
          }
        }
      }
    }
  });
}

async function claimRetryablePayout(payoutId: string): Promise<PayoutRecordWithBooking | null> {
  const result = await prisma.payout.updateMany({
    where: {
      id: payoutId,
      status: "failed"
    },
    data: {
      status: "pending",
      failureReason: null
    }
  });

  if (result.count === 0) {
    return null;
  }

  return getPayoutById(payoutId) as Promise<PayoutRecordWithBooking | null>;
}

function resolveWorkerName(payout: PayoutRecordWithBooking): string {
  const worker = payout.booking.worker;
  return worker?.fullName?.trim() || worker?.displayName?.trim() || worker?.user.name || "VeeduFix Worker";
}

function resolveWorkerPhone(payout: PayoutRecordWithBooking): string | null {
  const phone = payout.booking.worker?.user.phone?.replace(/\D/g, "") ?? null;
  if (!phone) {
    return null;
  }

  return phone;
}

function buildAttemptContext(payout: PayoutRecordWithBooking): PayoutAttemptContext {
  const worker = payout.booking.worker;
  if (!worker) {
    throw AppError.notFound("Assigned worker not found for payout");
  }

  const totalAmount = toNumber(payout.booking.totalAmount);
  const commissionPercent = getCommissionPercent();
  const commissionAmount = roundToTwo((totalAmount * commissionPercent) / 100);
  const amount = roundToTwo(totalAmount - commissionAmount);

  if (amount <= 0) {
    throw AppError.badRequest("Payout amount must be greater than zero");
  }

  const workerName = resolveWorkerName(payout);
  const workerPhone = resolveWorkerPhone(payout);
  const workerEmail = worker.user.email ?? undefined;

  if (!workerPhone) {
    throw AppError.badRequest("Worker phone number is required for payout");
  }

  const commonContact = {
    name: workerName,
    email: workerEmail,
    contact: workerPhone,
    type: "employee",
    reference_id: `worker-${worker.id}`
  };

  const mode = worker.upiId?.trim()
    ? ("UPI" as const)
    : ("IMPS" as const);

  const fundAccount =
    mode === "UPI"
      ? {
          account_type: "vpa",
          contact: commonContact,
          vpa: {
            address: worker.upiId!.trim()
          }
        }
      : {
          account_type: "bank_account",
          contact: commonContact,
          bank_account: {
            name: workerName,
            ifsc: worker.bankIfsc?.trim(),
            account_number: worker.bankAccountNumber?.trim()
          }
        };

  if (mode === "IMPS") {
    const bankAccountNumber = worker.bankAccountNumber?.trim();
    const bankIfsc = worker.bankIfsc?.trim();
    if (!bankAccountNumber || !bankIfsc) {
      throw AppError.badRequest("Worker bank account details are incomplete");
    }
  }

  return {
    payout,
    bookingCode: payout.booking.code,
    workerName,
    mode,
    fundAccount,
    amountPaise: Math.round(amount * 100)
  };
}

async function callRazorpayPayout(context: PayoutAttemptContext): Promise<RazorpayPayoutResponse> {
  const response = await fetch("https://api.razorpay.com/v1/payouts", {
    method: "POST",
    headers: {
      Authorization: getRazorpayAuthHeader(),
      "Content-Type": "application/json",
      "X-Payout-Idempotency": context.payout.id
    },
    body: JSON.stringify({
      account_number: getRazorpayAccountNumber(),
      amount: context.amountPaise,
      currency: "INR",
      mode: context.mode,
      purpose: "payout",
      queue_if_low_balance: false,
      reference_id: context.payout.id,
      narration: `VeeduFix payout`,
      fund_account: context.fundAccount,
      notes: {
        bookingId: context.payout.bookingId,
        bookingCode: context.bookingCode,
        workerId: context.payout.workerId,
        commissionAmount: context.payout.commissionAmount
      }
    })
  });

  const payload = (await response.json().catch(() => null)) as RazorpayPayoutResponse | { error?: unknown } | null;

  if (!response.ok) {
    throw new AppError(502, extractFailureReason(payload, `Razorpay payout request failed with status ${response.status}`));
  }

  if (!payload || typeof payload !== "object" || !("id" in payload)) {
    throw new AppError(502, "Razorpay payout response was malformed");
  }

  return payload as RazorpayPayoutResponse;
}

async function persistPayoutAttempt(
  payoutId: string,
  status: PayoutStatus,
  updates: Partial<Pick<Prisma.PayoutUpdateInput, "razorpayPayoutId" | "failureReason" | "status">>
) {
  return prisma.payout.update({
    where: { id: payoutId },
    data: {
      status,
      ...updates
    }
  });
}

async function attemptPayout(payout: PayoutRecordWithBooking): Promise<void> {
  const context = buildAttemptContext(payout);

  await persistPayoutAttempt(payout.id, "processing", {
    status: "processing",
    failureReason: null
  });

  try {
    const razorpayResponse = await callRazorpayPayout(context);

    await persistPayoutAttempt(payout.id, "success", {
      status: "success",
      razorpayPayoutId: razorpayResponse.id,
      failureReason: null
    });

    logger.info(
      {
        payoutId: payout.id,
        bookingId: payout.bookingId,
        bookingCode: payout.booking.code,
        razorpayPayoutId: razorpayResponse.id,
        mode: context.mode,
        amountPaise: context.amountPaise
      },
      "Worker payout released"
    );
  } catch (error) {
    const failureReason = error instanceof Error ? error.message : "Unknown payout failure";

    await persistPayoutAttempt(payout.id, "failed", {
      status: "failed",
      failureReason
    });

    logger.error(
      {
        error,
        payoutId: payout.id,
        bookingId: payout.bookingId,
        bookingCode: payout.booking.code,
        workerId: payout.workerId,
        mode: context.mode
      },
      "Worker payout failed"
    );
  }
}

async function createPendingPayoutRecord(bookingId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      worker: {
        include: {
          user: true
        }
      }
    }
  });

  if (!booking) {
    throw new Error("Booking not found");
  }

  if (!booking.workerId || !booking.worker) {
    throw new Error("Assigned worker not found for booking");
  }

  const totalAmount = toNumber(booking.totalAmount);
  const commissionPercent = getCommissionPercent();
  const commissionAmount = roundToTwo((totalAmount * commissionPercent) / 100);
  const amount = roundToTwo(totalAmount - commissionAmount);

  return prisma.payout.upsert({
    where: { bookingId },
    create: {
      bookingId,
      workerId: booking.workerId,
      amount,
      commissionAmount,
      status: "pending"
    },
    update: {
      workerId: booking.workerId,
      amount,
      commissionAmount,
      status: "pending",
      failureReason: null,
      razorpayPayoutId: null
    },
    include: {
      booking: {
        include: {
          worker: {
            include: {
              user: true
            }
          }
        }
      }
    }
  });
}

export async function releaseWorkerPayout(bookingId: string): Promise<void> {
  try {
    const existing = await getPayoutByBookingId(bookingId);
    if (existing && existing.status !== "failed") {
      logger.info(
        {
          bookingId,
          payoutId: existing.id,
          status: existing.status
        },
        "Payout already exists, skipping duplicate release"
      );
      return;
    }

    const payout = existing ? await claimRetryablePayout(existing.id) : await createPendingPayoutRecord(bookingId);
    if (!payout) {
      logger.info({ bookingId }, "Skipped payout release because the payout is no longer retryable");
      return;
    }

    await attemptPayout(payout);
  } catch (error) {
    logger.error(
      {
        error,
        bookingId
      },
      "Unable to release worker payout"
    );
  }
}

export async function retryPayout(payoutId: string) {
  const payout = await getPayoutById(payoutId);
  if (!payout) {
    throw new Error("Payout not found");
  }

  if (payout.status !== "failed") {
    throw new Error("Only failed payouts can be retried");
  }

  const updated = await claimRetryablePayout(payoutId);
  if (!updated) {
    throw new Error("Payout is no longer retryable");
  }

  await attemptPayout(updated);

  const result = await prisma.payout.findUnique({
    where: { id: payoutId },
    include: {
      booking: {
        include: {
          worker: {
            include: {
              user: true
            }
          }
        }
      }
    }
  });

  // Mask worker financial fields before returning to the client.
  // The actual payout was already processed above using the real data.
  if (result?.booking.worker) {
    return {
      ...result,
      booking: {
        ...result.booking,
        worker: maskWorkerFinancialFields(result.booking.worker)
      }
    };
  }

  return result;
}

export async function getAllPayouts(filters: PayoutFilters = {}) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 20;
  const skip = (page - 1) * limit;

  const where: Prisma.PayoutWhereInput = {
    ...(filters.status ? { status: filters.status } : {}),
    ...(filters.workerId ? { workerId: filters.workerId } : {})
  };

  const [total, items] = await prisma.$transaction([
    prisma.payout.count({ where }),
    prisma.payout.findMany({
      where,
      include: {
        booking: {
          include: {
            worker: {
              include: {
                user: true
              }
            }
          }
        }
      },
      orderBy: [{ createdAt: "desc" }],
      skip,
      take: limit
    })
  ]);

  return {
    items: items.map((item) => {
      if (!item.booking.worker) return item;
      return {
        ...item,
        booking: {
          ...item.booking,
          // Mask sensitive financial fields before serializing into the response.
          // The real field values remain in the DB and are used internally for payouts.
          worker: maskWorkerFinancialFields(item.booking.worker)
        }
      };
    }),
    page,
    limit,
    total,
    totalPages: Math.max(1, Math.ceil(total / limit))
  };
}

export async function listPayouts(filters: PayoutFilters = {}) {
  return getAllPayouts(filters);
}

export async function bulkRetryFailedPayouts(): Promise<{ attempted: number; succeeded: number; failed: number }> {
  const failedPayouts = await prisma.payout.findMany({
    where: { status: "failed" },
    include: {
      booking: {
        include: {
          worker: { include: { user: true } }
        }
      }
    },
    orderBy: { createdAt: "asc" },
    take: 50 // process in batches to avoid overwhelming the payment gateway
  });

  let succeeded = 0;
  let failed = 0;
  let attempted = 0;

  for (const payout of failedPayouts) {
    try {
      const claimed = await claimRetryablePayout(payout.id);
      if (!claimed) {
        continue;
      }

      attempted++;
      await attemptPayout(claimed);

      const result = await prisma.payout.findUnique({ where: { id: payout.id }, select: { status: true } });
      if (result?.status === "success") {
        succeeded++;
      } else {
        failed++;
      }
    } catch {
      failed++;
    }
  }

  return { attempted, succeeded, failed };
}

export async function exportPayoutsCsv(filters: PayoutFilters = {}): Promise<string> {
  const where: Prisma.PayoutWhereInput = {
    ...(filters.status ? { status: filters.status } : {}),
    ...(filters.workerId ? { workerId: filters.workerId } : {})
  };

  const items = await prisma.payout.findMany({
    where,
    include: {
      booking: {
        include: {
          worker: { include: { user: true } }
        }
      }
    },
    orderBy: [{ createdAt: "desc" }],
    take: 5000
  });

  const header = ["ID", "Booking Code", "Worker Name", "Amount (Rs.)", "Status", "Failure Reason", "Created At"];
  const rows = items.map((p) => {
    const worker = p.booking?.worker;
    const workerName = worker?.fullName ?? worker?.user?.name ?? "Unknown";
    const amount = (Number(p.amount ?? 0) / 100).toFixed(2);
    const reason = (p.failureReason ?? "").replace(/"/g, "'");
    return [p.id, p.booking?.code ?? "", workerName, amount, p.status, `"${reason}"`, p.createdAt.toISOString()].join(",");
  });

  return [header.join(","), ...rows].join("\n");
}
