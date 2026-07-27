import { BookingStatus, Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";

const ACTIVE_JOB_EXECUTION_STATUSES = ["assigned", "arrived", "in_progress"] as const;

export type OpsSummaryCounts = {
  activeJobsCount: number;
  dispatchFailuresCount: number;
  openDisputesCount: number;
  failedPayoutsCount: number;
  failedRefundsCount: number;
  pendingWorkerReviewsCount: number;
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

export type OpsAlertKind = "dispatch_failure" | "payout_failure" | "refund_failure";

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
    openDisputesCount,
    failedPayoutsCount,
    failedRefundsCount,
    pendingWorkerReviewsCount,
    liveBookings,
    dispatchFailureBookings,
    failedPayouts,
    failedRefunds
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
    prisma.booking.findMany({
      where: {
        status: BookingStatus.DISPATCH_FAILED
      },
      include: {
        customer: {
          select: {
            name: true
          }
        },
        city: {
          select: {
            name: true
          }
        }
      },
      orderBy: { updatedAt: "desc" }
    }),
    prisma.payout.findMany({
      where: {
        status: "failed"
      },
      include: {
        booking: {
          include: {
            customer: {
              select: {
                name: true
              }
            }
          }
        }
      },
      orderBy: { createdAt: "desc" }
    }),
    prisma.refund.findMany({
      where: {
        status: "failed"
      },
      include: {
        booking: {
          include: {
            customer: {
              select: {
                name: true
              }
            }
          }
        }
      },
      orderBy: { createdAt: "desc" }
    })
  ]);

  return {
    summary: {
      activeJobsCount,
      dispatchFailuresCount,
      openDisputesCount,
      failedPayoutsCount,
      failedRefundsCount,
      pendingWorkerReviewsCount
    },
    liveJobs: liveBookings.map(mapLiveJob),
    alerts: [
      ...dispatchFailureBookings.map(mapDispatchFailureAlert),
      ...failedPayouts.map(mapPayoutFailureAlert),
      ...failedRefunds.map(mapRefundFailureAlert)
    ].sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime())
  };
}
