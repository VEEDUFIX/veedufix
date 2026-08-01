import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";

type PayoutStatus = "pending" | "processing" | "success" | "failed";

export class WorkerProfileNotFoundError extends Error {
  constructor(message = "Worker profile not found") {
    super(message);
    this.name = "WorkerProfileNotFoundError";
  }
}

type WorkerEarningsSummaryRecord = {
  amount: number;
  createdAt: Date;
};

type WorkerEarningsTransactionRecord = Prisma.PayoutGetPayload<{
  include: {
    booking: {
      select: {
        id: true;
        code: true;
        services: {
          select: {
            service: {
              select: {
                name: true;
              };
            };
            serviceSubcategory: {
              select: {
                name: true;
              };
            };
          };
        };
      };
    };
  };
}>;

type EarningsFilterInput = {
  fromDate?: Date;
  toDate?: Date;
  status?: PayoutStatus;
};

type EarningsPaginationInput = {
  page: number;
  limit: number;
};

export type WorkerEarningsSummary = {
  todayTotal: number;
  weeklyTotal: number;
  monthlyTotal: number;
  chartData: Array<{
    date: string;
    amount: number;
  }>;
};

export type WorkerEarningsTransaction = {
  bookingId: string;
  bookingCode: string | null;
  serviceName: string;
  amount: number;
  commissionAmount: number;
  status: string;
  date: string;
};

function toNumber(value: Prisma.Decimal | number | string): number {
  return typeof value === "number" ? value : Number(value);
}

function startOfLocalDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function addDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

function startOfLocalMonth(date: Date): Date {
  const copy = new Date(date);
  copy.setDate(1);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function formatDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatDisplayDate(date: Date): string {
  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric"
  }).format(date);
}

function resolveServiceName(record: WorkerEarningsTransactionRecord): string {
  const names = new Set<string>();

  for (const item of record.booking.services) {
    const serviceName = item.service?.name?.trim() || item.serviceSubcategory?.name?.trim() || null;
    if (serviceName) {
      names.add(serviceName);
    }
  }

  return [...names].join(", ") || "Service booking";
}

async function getWorkerProfileIdByUserId(userId: string): Promise<string> {
  const profile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: {
      id: true
    }
  });

  if (!profile) {
    throw new WorkerProfileNotFoundError();
  }

  return profile.id;
}

async function getWorkerPayoutRecords(
  workerProfileId: string,
  where: Prisma.PayoutWhereInput
): Promise<WorkerEarningsSummaryRecord[]> {
  const payouts = await prisma.payout.findMany({
    where: {
      workerId: workerProfileId,
      ...where
    },
    select: {
      amount: true,
      createdAt: true
    }
  });

  return payouts.map((payout) => ({
    amount: toNumber(payout.amount),
    createdAt: payout.createdAt
  }));
}

export async function getWorkerEarningsSummary(workerUserId: string): Promise<WorkerEarningsSummary> {
  const workerProfileId = await getWorkerProfileIdByUserId(workerUserId);
  const now = new Date();
  const todayStart = startOfLocalDay(now);
  const tomorrowStart = addDays(todayStart, 1);
  const weekStart = startOfLocalDay(addDays(todayStart, -6));
  const monthStart = startOfLocalMonth(now);

  const [weekRecords, monthRecords] = await Promise.all([
    getWorkerPayoutRecords(workerProfileId, {
      status: "success",
      createdAt: {
        gte: weekStart,
        lt: tomorrowStart
      }
    }),
    getWorkerPayoutRecords(workerProfileId, {
      status: "success",
      createdAt: {
        gte: monthStart,
        lt: tomorrowStart
      }
    })
  ]);

  const todayKey = formatDateKey(todayStart);
  const chartMap = new Map<string, number>();
  let todayTotal = 0;

  for (const payout of weekRecords) {
    const dayKey = formatDateKey(payout.createdAt);
    chartMap.set(dayKey, (chartMap.get(dayKey) ?? 0) + payout.amount);

    if (dayKey === todayKey) {
      todayTotal += payout.amount;
    }
  }

  const chartData = Array.from({ length: 7 }, (_, index) => {
    const day = startOfLocalDay(addDays(weekStart, index));
    const key = formatDateKey(day);
    return {
      date: key,
      amount: chartMap.get(key) ?? 0
    };
  });

  return {
    todayTotal,
    weeklyTotal: weekRecords.reduce((total, payout) => total + payout.amount, 0),
    monthlyTotal: monthRecords.reduce((total, payout) => total + payout.amount, 0),
    chartData
  };
}

export async function getWorkerTransactionHistory(
  workerUserId: string,
  filters: EarningsFilterInput = {},
  pagination: EarningsPaginationInput
): Promise<{
  items: WorkerEarningsTransaction[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}> {
  const workerProfileId = await getWorkerProfileIdByUserId(workerUserId);
  const page = pagination.page;
  const limit = pagination.limit;
  const skip = (page - 1) * limit;
  const createdAtFilter: Prisma.DateTimeFilter = {};

  if (filters.fromDate) {
    createdAtFilter.gte = startOfLocalDay(filters.fromDate);
  }

  if (filters.toDate) {
    createdAtFilter.lt = addDays(startOfLocalDay(filters.toDate), 1);
  }

  const where: Prisma.PayoutWhereInput = {
    workerId: workerProfileId,
    ...(filters.status ? { status: filters.status } : {}),
    ...(Object.keys(createdAtFilter).length > 0 ? { createdAt: createdAtFilter } : {})
  };

  const [total, items] = await prisma.$transaction([
    prisma.payout.count({ where }),
    prisma.payout.findMany({
      where,
      include: {
        booking: {
          select: {
            id: true,
            code: true,
            services: {
              select: {
                service: {
                  select: {
                    name: true
                  }
                },
                serviceSubcategory: {
                  select: {
                    name: true
                  }
                }
              }
            }
          }
        }
      },
      orderBy: [
        {
          createdAt: "desc"
        }
      ],
      skip,
      take: limit
    })
  ]);

  return {
    items: items.map((item) => ({
      bookingId: item.bookingId,
      bookingCode: item.booking.code,
      serviceName: resolveServiceName(item),
      amount: toNumber(item.amount),
      commissionAmount: toNumber(item.commissionAmount),
      status: item.status,
      date: formatDisplayDate(item.createdAt)
    })),
    page,
    limit,
    total,
    totalPages: Math.max(1, Math.ceil(total / limit))
  };
}

export async function exportWorkerEarningsCsv(
  workerUserId: string,
  filters: EarningsFilterInput = {}
): Promise<string> {
  const workerProfileId = await getWorkerProfileIdByUserId(workerUserId);
  const createdAtFilter: Prisma.DateTimeFilter = {};

  if (filters.fromDate) {
    createdAtFilter.gte = startOfLocalDay(filters.fromDate);
  }

  if (filters.toDate) {
    createdAtFilter.lt = addDays(startOfLocalDay(filters.toDate), 1);
  }

  const where: Prisma.PayoutWhereInput = {
    workerId: workerProfileId,
    ...(filters.status ? { status: filters.status } : {}),
    ...(Object.keys(createdAtFilter).length > 0 ? { createdAt: createdAtFilter } : {})
  };

  const rows = await prisma.payout.findMany({
    where,
    include: {
      booking: {
        select: {
          code: true,
          services: {
            select: {
              service: { select: { name: true } },
              serviceSubcategory: { select: { name: true } }
            }
          }
        }
      }
    },
    orderBy: [{ createdAt: "desc" }]
  });

  const header = "booking_code,service_name,amount,commission_amount,status,date";
  const lines = rows.map((row) => {
    const serviceName = resolveServiceName(row as WorkerEarningsTransactionRecord);
    return [
      row.booking.code,
      serviceName,
      toNumber(row.amount).toFixed(2),
      toNumber(row.commissionAmount).toFixed(2),
      row.status,
      row.createdAt.toISOString()
    ]
      .map((value) => `"${String(value).replace(/"/g, '""')}"`)
      .join(",");
  });

  return [header, ...lines].join("\n");
}
