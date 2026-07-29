import { BookingStatus, Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { publishNotificationEvent } from "../../lib/realtime.js";

const ACTIVE_JOB_EXECUTION_STATUSES = ["assigned", "arrived", "in_progress"] as const;
const DEFAULT_ALERT_PAGE_SIZE = 25;
const ALERT_KIND_BY_TYPE = {
  dispatch_failure: "dispatch_failure",
  payout_failure: "payout_failure",
  refund_failure: "refund_failure",
  payment_mismatch: "payment_mismatch"
} as const;

export type OpsSummaryCounts = {
  activeJobsCount: number;
  dispatchFailuresCount: number;
  openDisputesCount: number;
  failedPayoutsCount: number;
  failedRefundsCount: number;
  pendingWorkerReviewsCount: number;
  totalRevenue: number;
  totalBookings: number;
  completedBookings: number;
  todaysNewWorkers: number;
};

export type OpsLiveJobChecklistItem = {
  label: string;
  complete: boolean;
};

export type OpsLiveJob = {
  bookingId: string;
  bookingCode: string;
  bookingStatus: BookingStatus;
  customerName: string;
  customerAvatarUrl: string | null;
  workerName: string | null;
  workerAvatarUrl: string | null;
  cityName: string;
  serviceCategories: string[];
  status: string;
  scheduledAt: Date;
  assignedAt: Date;
  elapsedMinutes: number;
  beforePhotos: string[];
  afterPhotos: string[];
  checklistItems: OpsLiveJobChecklistItem[];
  notes: string | null;
  customerNotes: string | null;
  workerLat: number | null;
  workerLng: number | null;
  updatedAt: Date;
};

export type OpsAlertKind = "dispatch_failure" | "payout_failure" | "refund_failure" | "payment_mismatch";

export type OpsAlert = {
  id: string;
  kind: OpsAlertKind;
  title: string;
  message: string;
  sourceId: string | null;
  bookingId: string | null;
  bookingCode: string | null;
  customerName: string | null;
  amount: number | null;
  createdAt: Date;
  retryAvailable: boolean;
};

export type OpsAlertRecord = Prisma.OpsAlertGetPayload<{
  select: {
    id: true;
    sourceId: true;
    type: true;
    bookingId: true;
    message: true;
    metadata: true;
    severity: true;
    status: true;
    createdAt: true;
  };
}>;

export type OpsAlertListFilters = {
  type?: OpsAlertKind;
  severity?: "low" | "medium" | "high" | "critical";
  status?: "open" | "acknowledged" | "resolved";
  page?: number;
  pageSize?: number;
};

type OpsAlertMetadata = {
  bookingCode?: string;
  customerName?: string;
  amount?: number | null;
  retryAvailable?: boolean;
  title?: string;
  sourceLabel?: string;
  expectedAmountPaise?: number;
  actualCapturedAmountPaise?: number;
  timestamp?: string;
  customerId?: string;
  [key: string]: unknown;
};

export type OpsOverview = {
  summary: OpsSummaryCounts;
  liveJobs: OpsLiveJob[];
  alerts: OpsAlert[];
};

function toNumber(value: Prisma.Decimal | number | string | null | undefined): number {
  if (value === null || value === undefined) {
    return 0;
  }

  return typeof value === "number" ? value : Number(value);
}

function elapsedMinutesSince(date: Date): number {
  return Math.max(0, Math.floor((Date.now() - date.getTime()) / 60000));
}

function resolveWorkerName(worker: {
  fullName?: string | null;
  displayName?: string | null;
  user?: { name?: string | null; avatarUrl?: string | null } | null;
} | null | undefined): string | null {
  const fullName = worker?.fullName?.trim();
  if (fullName) {
    return fullName;
  }

  const displayName = worker?.displayName?.trim();
  if (displayName) {
    return displayName;
  }

  const fallback = worker?.user?.name?.trim();
  return fallback || null;
}

function resolveServiceCategories(
  services: Array<{
    service?: {
      category?: { name?: string | null } | null;
      subcategory?: { category?: { name?: string | null } | null } | null;
      name?: string | null;
    } | null;
    serviceSubcategory?: {
      category?: { name?: string | null } | null;
      name?: string | null;
    } | null;
  }>
): string[] {
  const names = new Set<string>();

  for (const item of services) {
    const categoryName =
      item.service?.category?.name?.trim() ||
      item.service?.subcategory?.category?.name?.trim() ||
      item.serviceSubcategory?.category?.name?.trim() ||
      null;

    if (categoryName) {
      names.add(categoryName);
    }
  }

  return [...names];
}

function normalizeChecklist(checklist: unknown): OpsLiveJobChecklistItem[] {
  if (!checklist) {
    return [];
  }

  if (Array.isArray(checklist)) {
    return checklist.map((item, index) => {
      if (typeof item === "string") {
        return {
          label: item.trim() || `Item ${index + 1}`,
          complete: item.trim().length > 0
        };
      }

      if (item && typeof item === "object") {
        const record = item as Record<string, unknown>;
        const label =
          (typeof record.label === "string" && record.label.trim()) ||
          (typeof record.name === "string" && record.name.trim()) ||
          (typeof record.title === "string" && record.title.trim()) ||
          `Item ${index + 1}`;
        const complete =
          typeof record.completed === "boolean"
            ? record.completed
            : typeof record.checked === "boolean"
              ? record.checked
              : typeof record.done === "boolean"
                ? record.done
                : typeof record.isComplete === "boolean"
                  ? record.isComplete
                  : true;

        return { label, complete };
      }

      return {
        label: `Item ${index + 1}`,
        complete: item !== null && item !== undefined
      };
    });
  }

  if (typeof checklist === "object") {
    return Object.entries(checklist as Record<string, unknown>).map(([key, value], index) => ({
      label: key || `Item ${index + 1}`,
      complete:
        typeof value === "boolean"
          ? value
          : value !== null && value !== undefined && String(value).trim() !== ""
    }));
  }

  return [
    {
      label: String(checklist),
      complete: true
    }
  ];
}

function parseAlertMetadata(metadata: Prisma.JsonValue | null | undefined): OpsAlertMetadata {
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) {
    return {};
  }

  return metadata as OpsAlertMetadata;
}

function resolveAlertKind(type: string): OpsAlertKind {
  switch (type) {
    case "dispatch_failure":
    case "payout_failure":
    case "refund_failure":
    case "payment_mismatch":
      return type;
    default:
      return "dispatch_failure";
  }
}

function mapOpsAlert(alert: OpsAlertRecord): OpsAlert {
  const metadata = parseAlertMetadata(alert.metadata);
  const retryAvailable = typeof metadata.retryAvailable === "boolean" ? metadata.retryAvailable : alert.type !== "payment_mismatch";

  return {
    id: alert.id,
    kind: resolveAlertKind(alert.type),
    title:
      (typeof metadata.title === "string" && metadata.title.trim()) ||
      `${alert.type.replace(/_/g, " ")}${metadata.bookingCode ? ` for booking ${metadata.bookingCode}` : ""}`,
    message: alert.message,
    sourceId: alert.sourceId,
    bookingId: alert.bookingId,
    bookingCode: typeof metadata.bookingCode === "string" ? metadata.bookingCode : null,
    customerName: typeof metadata.customerName === "string" ? metadata.customerName : null,
    amount: typeof metadata.amount === "number" ? metadata.amount : null,
    createdAt: alert.createdAt,
    retryAvailable
  };
}

function normalizeAlertKind(value?: string): OpsAlertKind | undefined {
  if (!value) {
    return undefined;
  }

  return resolveAlertKind(value);
}

async function notifyAdminAlertRecipients(title: string, body: string, data: Record<string, unknown>): Promise<void> {
  const admins = await prisma.user.findMany({
    where: { role: "ADMIN", isActive: true },
    select: { id: true }
  });

  await Promise.all(
    admins.map((admin) =>
      publishNotificationEvent({
        userId: admin.id,
        title,
        body,
        type: "ops_alert",
        data
      })
    )
  );
}

export async function raiseOpsAlert(input: {
  type: OpsAlertKind;
  sourceId: string;
  bookingId?: string | null;
  severity?: "low" | "medium" | "high" | "critical";
  status?: "open" | "acknowledged" | "resolved";
  message: string;
  metadata?: OpsAlertMetadata;
}): Promise<OpsAlertRecord> {
  const alert = await prisma.opsAlert.upsert({
    where: { sourceId: input.sourceId },
    create: {
      sourceId: input.sourceId,
      type: input.type,
      bookingId: input.bookingId ?? null,
      message: input.message,
      metadata: (input.metadata ?? {}) as Prisma.InputJsonValue,
      severity: input.severity ?? "high",
      status: input.status ?? "open"
    },
    update: {
      type: input.type,
      bookingId: input.bookingId ?? null,
      message: input.message,
      metadata: (input.metadata ?? {}) as Prisma.InputJsonValue,
      severity: input.severity ?? "high",
      status: input.status ?? "open"
    },
    select: {
      id: true,
      sourceId: true,
      type: true,
      bookingId: true,
      message: true,
      metadata: true,
      severity: true,
      status: true,
      createdAt: true
    }
  });

  const metadata = parseAlertMetadata(alert.metadata);
  const title = typeof metadata.title === "string" && metadata.title.trim() ? metadata.title.trim() : alert.type.replace(/_/g, " ");

  await notifyAdminAlertRecipients(title, alert.message, {
    alertId: alert.id,
    type: alert.type,
    sourceId: alert.sourceId,
    bookingId: alert.bookingId,
    severity: alert.severity,
    status: alert.status,
    createdAt: alert.createdAt.toISOString(),
    ...metadata
  });

  return alert;
}

export async function listOpsAlerts(filters: OpsAlertListFilters = {}): Promise<{
  items: OpsAlert[];
  total: number;
  page: number;
  pageSize: number;
}> {
  const page = filters.page ?? 1;
  const pageSize = filters.pageSize ?? DEFAULT_ALERT_PAGE_SIZE;
  const where: Prisma.OpsAlertWhereInput = {
    ...(filters.type ? { type: filters.type } : {}),
    ...(filters.severity ? { severity: filters.severity } : {}),
    ...(filters.status ? { status: filters.status } : {})
  };

  const [items, total] = await Promise.all([
    prisma.opsAlert.findMany({
      where,
      orderBy: [{ createdAt: "desc" }],
      take: pageSize,
      skip: (page - 1) * pageSize,
      select: {
        id: true,
        sourceId: true,
        type: true,
        bookingId: true,
        message: true,
        metadata: true,
        severity: true,
        status: true,
        createdAt: true
      }
    }),
    prisma.opsAlert.count({ where })
  ]);

  return {
    items: items.map(mapOpsAlert),
    total,
    page,
    pageSize
  };
}

function mapLiveJob(
  booking: Prisma.BookingGetPayload<{
    include: {
      customer: {
        select: {
          name: true;
          avatarUrl: true;
        };
      };
      worker: {
        include: {
          user: {
            select: {
              avatarUrl: true;
            };
          };
        };
      };
      city: {
        select: {
          name: true;
        };
      };
      jobExecution: true;
      services: {
        include: {
          service: {
            include: {
              category: true;
              subcategory: {
                include: {
                  category: true;
                };
              };
            };
          };
          serviceSubcategory: {
            include: {
              category: true;
            };
          };
        };
      };
    };
  }>
): OpsLiveJob {
  const execution = booking.jobExecution!;
  const workerName = resolveWorkerName(booking.worker);
  return {
    bookingId: booking.id,
    bookingCode: booking.code,
    bookingStatus: booking.status,
    customerName: booking.customer.name,
    customerAvatarUrl: booking.customer.avatarUrl ?? null,
    workerName,
    workerAvatarUrl: booking.worker?.user.avatarUrl ?? null,
    cityName: booking.city.name,
    serviceCategories: resolveServiceCategories(booking.services),
    status: execution.status,
    scheduledAt: booking.scheduledAt,
    assignedAt: execution.createdAt,
    elapsedMinutes: elapsedMinutesSince(execution.createdAt),
    beforePhotos: execution.beforePhotos,
    afterPhotos: execution.afterPhotos,
    checklistItems: normalizeChecklist(execution.checklist),
    notes: booking.notes ?? null,
    customerNotes: booking.customerNotes ?? null,
    workerLat: execution.workerLat ?? null,
    workerLng: execution.workerLng ?? null,
    updatedAt: execution.updatedAt
  };
}

function mapDispatchFailureAlert(
  booking: Prisma.BookingGetPayload<{
    include: {
      customer: {
        select: {
          name: true;
        };
      };
      city: {
        select: {
          name: true;
        };
      };
    };
  }>
): OpsAlert {
  return {
    id: `dispatch-${booking.id}`,
    kind: "dispatch_failure",
    title: `Dispatch failed for booking ${booking.code}`,
    message: `${booking.customer.name} in ${booking.city.name} needs another dispatch attempt.`,
    sourceId: booking.id,
    bookingId: booking.id,
    bookingCode: booking.code,
    customerName: booking.customer.name,
    amount: null,
    createdAt: booking.updatedAt,
    retryAvailable: true
  };
}

function mapPayoutFailureAlert(
  payout: Prisma.PayoutGetPayload<{
    include: {
      booking: {
        include: {
          customer: {
            select: {
              name: true;
            };
          };
        };
      };
    };
  }>
): OpsAlert {
  return {
    id: `payout-${payout.id}`,
    kind: "payout_failure",
    title: `Payout failed for booking ${payout.booking.code}`,
    message: payout.failureReason || "The worker payout needs a retry.",
    sourceId: payout.id,
    bookingId: payout.bookingId,
    bookingCode: payout.booking.code,
    customerName: payout.booking.customer.name,
    amount: toNumber(payout.amount),
    createdAt: payout.createdAt,
    retryAvailable: true
  };
}

function mapRefundFailureAlert(
  refund: Prisma.RefundGetPayload<{
    include: {
      booking: {
        include: {
          customer: {
            select: {
              name: true;
            };
          };
        };
      };
    };
  }>
): OpsAlert {
  return {
    id: `refund-${refund.id}`,
    kind: "refund_failure",
    title: `Refund failed for booking ${refund.booking.code}`,
    message: refund.failureReason || "The refund needs manual follow-up.",
    sourceId: refund.id,
    bookingId: refund.bookingId,
    bookingCode: refund.booking.code,
    customerName: refund.booking.customer.name,
    amount: refund.amount,
    createdAt: refund.createdAt,
    retryAvailable: true
  };
}

export async function getOpsOverview(): Promise<OpsOverview> {
  const [
    activeJobsCount,
    dispatchFailuresCount,
    totalRevenueQuery,
    totalBookings,
    completedBookings,
    todaysNewWorkers,
    openDisputesCount,
    failedPayoutsCount,
    failedRefundsCount,
    pendingWorkerReviewsCount,
    liveBookings,
    alertPage
  ] = await Promise.all([
    prisma.jobExecution.count({
      where: {
        status: { in: [...ACTIVE_JOB_EXECUTION_STATUSES] }
      }
    }),
    prisma.booking.count({
      where: {
        status: BookingStatus.DISPATCH_FAILED
      }
    }),
    prisma.booking.aggregate({
      where: { status: BookingStatus.COMPLETED },
      _sum: { totalAmount: true }
    }),
    prisma.booking.count(),
    prisma.booking.count({
      where: { status: BookingStatus.COMPLETED }
    }),
    prisma.workerProfile.count({
      where: {
        createdAt: {
          gte: new Date(new Date().setHours(0, 0, 0, 0))
        }
      }
    }),
    prisma.dispute.count({
      where: {
        status: { in: ["open", "under_review"] }
      }
    }),
    prisma.payout.count({
      where: {
        status: "failed"
      }
    }),
    prisma.refund.count({
      where: {
        status: "failed"
      }
    }),
    prisma.workerProfile.count({
      where: {
        verificationStatus: "PENDING",
        onboardingStatus: "under_review"
      }
    }),
    prisma.booking.findMany({
      where: {
        jobExecution: {
          is: {
            status: { in: [...ACTIVE_JOB_EXECUTION_STATUSES] }
          }
        }
      },
      include: {
        customer: {
          select: {
            name: true,
            avatarUrl: true
          }
        },
        worker: {
          include: {
            user: {
              select: {
                avatarUrl: true
              }
            }
          }
        },
        city: {
          select: {
            name: true
          }
        },
        jobExecution: true,
        services: {
          include: {
            service: {
              include: {
                category: true,
                subcategory: {
                  include: {
                    category: true
                  }
                }
              }
            },
            serviceSubcategory: {
              include: {
                category: true
              }
            }
          }
        }
      },
      orderBy: [
        { scheduledAt: "asc" },
        { updatedAt: "desc" }
      ]
    }),
    listOpsAlerts({
      status: "open",
      pageSize: DEFAULT_ALERT_PAGE_SIZE
    })
  ]);

  return {
    summary: {
      activeJobsCount,
      dispatchFailuresCount,
      openDisputesCount,
      failedPayoutsCount,
      failedRefundsCount,
      pendingWorkerReviewsCount,
      totalRevenue: toNumber(totalRevenueQuery?._sum?.totalAmount),
      totalBookings: totalBookings,
      completedBookings: completedBookings,
      todaysNewWorkers: todaysNewWorkers,
    },
    liveJobs: liveBookings.map(mapLiveJob),
    alerts: alertPage.items
  };
}
