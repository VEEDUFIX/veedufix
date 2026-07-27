import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import { processRefund } from "../refund/refund.service.js";

export class BookingNotFoundError extends Error {
  constructor(message = "Booking not found") {
    super(message);
    this.name = "BookingNotFoundError";
  }
}

export class DisputeNotFoundError extends Error {
  constructor(message = "Dispute not found") {
    super(message);
    this.name = "DisputeNotFoundError";
  }
}

export class DisputeAccessError extends Error {
  constructor(message = "You cannot raise a dispute for this booking") {
    super(message);
    this.name = "DisputeAccessError";
  }
}

export class DisputeWindowExpiredError extends Error {
  constructor(message = "The dispute window has expired") {
    super(message);
    this.name = "DisputeWindowExpiredError";
  }
}

export class DisputeConflictError extends Error {
  constructor(message = "A dispute already exists for this booking") {
    super(message);
    this.name = "DisputeConflictError";
  }
}

export type DisputeResolution = "refund" | "reject";

type DisputeRecord = {
  id: string;
  bookingId: string;
  raisedBy: string;
  reason: string;
  status: string;
  resolutionNote: string | null;
  resolvedBy: string | null;
  resolvedAt: Date | null;
  refundId: string | null;
  createdAt: Date;
};

type BookingEvidence = {
  id: string;
  code: string;
  customerId: string;
  cityId: string;
  totalAmount: Prisma.Decimal;
  customerNotes: string | null;
  city: {
    id: string;
    name: string;
    slug: string;
  };
  worker: {
    id: string;
    fullName: string | null;
    displayName: string | null;
    user: {
      name: string | null;
      avatarUrl: string | null;
    };
  } | null;
  jobExecution: {
    status: string;
    beforePhotos: string[];
    afterPhotos: string[];
    checklist: unknown;
    completedAt: Date | null;
  } | null;
};

type DisputeEvidence = {
  dispute: DisputeRecord;
  booking: BookingEvidence;
};

type OpenDisputeFilters = {
  city?: string;
  page?: number;
  pageSize?: number;
};

type OpenDisputeListItem = DisputeRecord & {
  booking: {
    id: string;
    code: string;
    city: {
      id: string;
      name: string;
      slug: string;
    };
    customer: {
      id: string;
      name: string;
      email: string | null;
      phone: string | null;
    };
    jobExecution: {
      status: string;
      completedAt: Date | null;
      beforePhotos: string[];
      afterPhotos: string[];
      checklist: unknown;
    } | null;
  };
};

function getDisputeCutoff(): Date {
  return new Date(Date.now() - 48 * 60 * 60 * 1000);
}

async function notifyAdminsOfDispute(dispute: DisputeRecord) {
  const admins = await prisma.user.findMany({
    where: {
      role: "ADMIN",
      isActive: true
    },
    select: {
      id: true
    }
  });

  await Promise.all(
    admins.map((admin) =>
      publishNotificationEvent({
        userId: admin.id,
        title: "New dispute raised",
        body: "A completed booking has been disputed and needs review.",
        type: "ops_alert",
        data: {
          disputeId: dispute.id,
          bookingId: dispute.bookingId,
          reason: dispute.reason,
          status: dispute.status
        }
      })
    )
  );
}

async function getBookingForDispute(bookingId: string): Promise<BookingEvidence> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      code: true,
      customerId: true,
      cityId: true,
      totalAmount: true,
      customerNotes: true,
      city: {
        select: {
          id: true,
          name: true,
          slug: true
        }
      },
      worker: {
        select: {
          id: true,
          fullName: true,
          displayName: true,
          user: {
            select: {
              name: true,
              avatarUrl: true
            }
          }
        }
      },
      jobExecution: {
        select: {
          status: true,
          beforePhotos: true,
          afterPhotos: true,
          checklist: true,
          completedAt: true
        }
      }
    }
  });

  if (!booking) {
    throw new BookingNotFoundError();
  }

  return booking;
}

async function getDisputeForResolution(disputeId: string) {
  const dispute = await prisma.dispute.findUnique({
    where: { id: disputeId },
    include: {
      booking: {
        select: {
          id: true,
          code: true,
          totalAmount: true,
          status: true
        }
      }
    }
  });

  if (!dispute) {
    throw new DisputeNotFoundError();
  }

  return dispute;
}

export async function raiseDispute(
  bookingId: string,
  customerId: string,
  reason: string
): Promise<DisputeRecord> {
  const booking = await getBookingForDispute(bookingId);

  if (booking.customerId !== customerId) {
    throw new DisputeAccessError();
  }

  const execution = booking.jobExecution;
  const cutoff = getDisputeCutoff();
  const isWithinWindow = Boolean(
    execution &&
      execution.status === "completed" &&
      execution.completedAt &&
      execution.completedAt.getTime() >= cutoff.getTime()
  );

  if (!isWithinWindow) {
    throw new DisputeWindowExpiredError();
  }

  const existing = await prisma.dispute.findFirst({
    where: {
      bookingId,
      status: {
        in: ["open", "under_review"]
      }
    },
    select: {
      id: true
    }
  });

  if (existing) {
    throw new DisputeConflictError();
  }

  const dispute = await prisma.dispute.create({
    data: {
      bookingId,
      raisedBy: customerId,
      reason,
      status: "open"
    }
  });

  await notifyAdminsOfDispute(dispute);

  return dispute;
}

export async function getDisputeEvidence(disputeId: string): Promise<DisputeEvidence> {
  const dispute = await prisma.dispute.findUnique({
    where: { id: disputeId },
    include: {
      booking: {
        select: {
          id: true,
          code: true,
          customerId: true,
          cityId: true,
          totalAmount: true,
          city: {
            select: {
              id: true,
              name: true,
              slug: true
            }
          },
          customerNotes: true,
          worker: {
            select: {
              id: true,
              fullName: true,
              displayName: true,
              user: {
                select: {
                  name: true,
                  avatarUrl: true
                }
              }
            }
          },
          jobExecution: {
            select: {
              status: true,
              beforePhotos: true,
              afterPhotos: true,
              checklist: true,
              completedAt: true
            }
          }
        }
      }
    }
  });

  if (!dispute) {
    throw new DisputeNotFoundError();
  }

  return {
    dispute,
    booking: dispute.booking
  };
}

export async function listOpenDisputes(filters: OpenDisputeFilters = {}): Promise<{
  items: OpenDisputeListItem[];
  total: number;
  page: number;
  pageSize: number;
}> {
  const page = filters.page ?? 1;
  const pageSize = filters.pageSize ?? 20;
  const city = filters.city?.trim();
  const where = {
    status: {
      in: ["open", "under_review"]
    },
    ...(city
      ? {
          booking: {
            city: {
              OR: [
                { name: { contains: city, mode: "insensitive" as const } },
                { slug: { contains: city, mode: "insensitive" as const } }
              ]
            }
          }
        }
      : {})
  };

  const [items, total] = await Promise.all([
    prisma.dispute.findMany({
      where,
      orderBy: [{ createdAt: "desc" }],
      take: pageSize,
      skip: (page - 1) * pageSize,
      include: {
        booking: {
          select: {
            id: true,
            code: true,
            city: {
              select: {
                id: true,
                name: true,
                slug: true
              }
            },
            customer: {
              select: {
                id: true,
                name: true,
                email: true,
                phone: true
              }
            },
            customerNotes: true,
            worker: {
              select: {
                id: true,
                fullName: true,
                displayName: true,
                user: {
                  select: {
                    name: true,
                    avatarUrl: true
                  }
                }
              }
            },
            jobExecution: {
              select: {
                status: true,
                completedAt: true,
                beforePhotos: true,
                afterPhotos: true,
                checklist: true
              }
            }
          }
        }
      }
    }),
    prisma.dispute.count({ where })
  ]);

  return {
    items,
    total,
    page,
    pageSize
  };
}

export async function resolveDispute(
  disputeId: string,
  adminId: string,
  resolution: DisputeResolution,
  note: string
): Promise<DisputeRecord> {
  const dispute = await getDisputeForResolution(disputeId);

  if (dispute.status !== "open" && dispute.status !== "under_review") {
    throw new DisputeConflictError("This dispute has already been resolved");
  }

  if (resolution === "refund") {
    const refund = await processRefund(dispute.bookingId, dispute.booking.totalAmount, note);
    await prisma.refund.update({
      where: { id: refund.id },
      data: {
        disputeId: dispute.id
      }
    });

    await prisma.dispute.update({
      where: { id: dispute.id },
      data: {
        refundId: refund.id
      }
    });
  }

  return prisma.dispute.update({
    where: { id: disputeId },
    data: {
      status: resolution === "refund" ? "resolved_refund" : "resolved_rejected",
      resolutionNote: note,
      resolvedBy: adminId,
      resolvedAt: new Date()
    }
  });
}

export const disputeService = {
  raiseDispute,
  getDisputeEvidence,
  listOpenDisputes,
  resolveDispute
};
