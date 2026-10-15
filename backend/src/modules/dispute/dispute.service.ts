import { BookingStatus, Prisma } from "@prisma/client";
import { randomUUID } from "node:crypto";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import { getRemainingOriginalBookingChargeAmount, processRefund, RefundProcessingError } from "../refund/refund.service.js";
import { assertAssignedPartnerAvailableForRemedy, MatchingError } from "../matching/matching.service.js";

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

export class DisputeValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DisputeValidationError";
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
  status: string;
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
  services: Array<{ id: string; serviceId: string | null; service?: { name: string } | null; guaranteePolicySnapshot: Prisma.JsonValue | null }>;
  payments?: Array<{ id: string; status: string; amount: Prisma.Decimal; currency: string; createdAt: Date; customQuoteRevisionId: string | null }>;
};

type DisputeEvidence = {
  dispute: DisputeRecord;
  booking: BookingEvidence;
};

type OpenDisputeFilters = {
  city?: string;
  status?: "all" | "open" | "under_review" | "refund_pending" | "action_required" | "approved" | "closed" | "resolved_rework" | "resolved_refund" | "resolved_rejected";
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

async function deliverClaimNotification(input: {
  userId: string;
  title: string;
  body: string;
  type: string;
  data: Record<string, unknown>;
  dedupeKey: string;
}) {
  try {
    await prisma.notification.create({
      data: {
        userId: input.userId,
        title: input.title,
        body: input.body,
        type: input.type,
        data: input.data as Prisma.InputJsonValue,
        dedupeKey: input.dedupeKey
      }
    });
  } catch (error) {
    if (isUniqueConstraintError(error)) return;
    logger.warn({ error, userId: input.userId, dedupeKey: input.dedupeKey }, "Could not persist claim notification");
    return;
  }
  await publishNotificationEvent({
    userId: input.userId,
    title: input.title,
    body: input.body,
    type: input.type,
    data: input.data
  }).catch((error) => logger.warn({ error, userId: input.userId, dedupeKey: input.dedupeKey }, "Claim notification delivery failed"));
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
      deliverClaimNotification({
        userId: admin.id,
        title: "New dispute raised",
        body: "A completed booking has been disputed and needs review.",
        type: "ops_alert",
        data: {
          disputeId: dispute.id,
          bookingId: dispute.bookingId,
          reason: dispute.reason,
          status: dispute.status
        },
        dedupeKey: `${dispute.id}:submitted`
      }).catch((error) => logger.warn({ error, adminId: admin.id, disputeId: dispute.id }, "Claim notification delivery failed"))
    )
  );
}

async function notifyClaimParties(disputeId: string, type: string, message: string, dedupeSuffix: string) {
  try {
    const dispute = await prisma.dispute.findUnique({
      where: { id: disputeId },
      select: {
        bookingId: true,
        booking: { select: { customerId: true, worker: { select: { userId: true } } } }
      }
    });
    if (!dispute) return;
    const recipientIds = [...new Set(
      [dispute.booking.customerId, dispute.booking.worker?.userId]
        .filter((value): value is string => Boolean(value))
    )];
    await Promise.all(recipientIds.map((userId) => deliverClaimNotification({
      userId,
      title: "Service claim updated",
      body: message || "There is an update to a service claim.",
      type: "service_claim_update",
      data: { disputeId, bookingId: dispute.bookingId, eventType: type },
      dedupeKey: `${disputeId}:${dedupeSuffix}`
    })));
  } catch (error) {
    logger.warn({ error, disputeId, type }, "Could not notify claim participants");
  }
}

async function notifyAdminsOfClaimUpdate(disputeId: string, message: string, dedupeSuffix: string) {
  try {
    const admins = await prisma.user.findMany({
      where: { role: "ADMIN", isActive: true },
      select: { id: true }
    });
    await Promise.all(admins.map((admin) => deliverClaimNotification({
      userId: admin.id,
      title: "Service claim needs review",
      body: message,
      type: "ops_alert",
      data: { disputeId, eventType: "claim_update" },
      dedupeKey: `${disputeId}:${dedupeSuffix}`
    })));
  } catch (error) {
    logger.warn({ error, disputeId }, "Could not notify admins of claim update");
  }
}

function isUniqueConstraintError(error: unknown): error is Prisma.PrismaClientKnownRequestError {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002";
}

type ClaimBookingService = {
  serviceId: string | null;
  guaranteePolicySnapshot: Prisma.JsonValue | null;
};

function isEnabledGuaranteePolicy(
  snapshot: Prisma.JsonValue | null
): snapshot is Prisma.JsonObject {
  return Boolean(
    snapshot &&
      typeof snapshot === "object" &&
      !Array.isArray(snapshot) &&
      (snapshot as Prisma.JsonObject).enabled === true
  );
}

function resolveClaimService(
  services: ClaimBookingService[],
  serviceId: string | null
): ClaimBookingService | undefined {
  if (serviceId) return services.find((service) => service.serviceId === serviceId);

  const enabledServices = services.filter((service) =>
    isEnabledGuaranteePolicy(service.guaranteePolicySnapshot)
  );
  if (enabledServices.length === 1) return enabledServices[0];
  if (enabledServices.length > 1) return undefined;

  const selectableServices = services.filter(
    (service) => service.serviceId !== null || service.guaranteePolicySnapshot !== null
  );
  return selectableServices.length === 1 ? selectableServices[0] : undefined;
}

async function findClaimEventByKey(disputeId: string, key: string) {
  return prisma.disputeEvent.findFirst({
    where: { disputeId, idempotencyKey: key },
    select: { id: true, actorId: true, message: true, type: true }
  });
}

async function getBookingForDispute(bookingId: string): Promise<BookingEvidence> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      code: true,
      status: true,
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
      },
      services: { select: { id: true, serviceId: true, guaranteePolicySnapshot: true } }
    }
  });

  if (!booking) {
    throw new BookingNotFoundError();
  }

  return booking;
}

async function getDisputeForResolution(
  disputeId: string,
  options: { includeInternal?: boolean } = { includeInternal: true }
) {
  const dispute = await prisma.dispute.findUnique({
    where: { id: disputeId },
    include: {
      history: {
        ...(!options.includeInternal
          ? { where: { visibility: { in: ["CUSTOMER", "PARTNER"] } } }
          : {}),
        orderBy: { createdAt: "asc" }
      },
      booking: {
        select: {
          id: true,
          code: true,
          totalAmount: true,
          status: true,
          services: { select: { serviceId: true, guaranteePolicySnapshot: true } }
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
  reason: string,
  input: { issueCategory?: string; serviceId?: string; idempotencyKey?: string; evidencePhotoIds?: string[] } = {}
): Promise<DisputeRecord> {
  const booking = await getBookingForDispute(bookingId);

  if (booking.customerId !== customerId) {
    throw new DisputeAccessError();
  }

  const execution = booking.jobExecution;
  const cutoff = getDisputeCutoff();
  const bookedServices = booking.services ?? [];
  const enabledPolicyServices = bookedServices.filter((item) => {
    return isEnabledGuaranteePolicy(item.guaranteePolicySnapshot);
  });
  const selectedService = resolveClaimService(bookedServices, input.serviceId ?? null);
  if (input.serviceId && !selectedService) {
    throw new DisputeValidationError("Select a service included in this booking");
  }
  if (!input.serviceId && enabledPolicyServices.length > 1) {
    throw new DisputeValidationError("Select which booked service has the reported issue");
  }
  const rawPolicy = selectedService?.guaranteePolicySnapshot;
  const configured = isEnabledGuaranteePolicy(rawPolicy ?? null)
    ? [rawPolicy]
    : [];
  const allowedWindow = configured.length > 0
    ? Math.min(...configured.map((value) => Number(value.claimWindowDays) || 0))
    : 48 / 24;
  const effectiveCutoff = configured.length > 0
    ? new Date(Date.now() - allowedWindow * 24 * 60 * 60 * 1000)
    : cutoff;
  const isWithinWindow = Boolean(
    booking.status === BookingStatus.COMPLETED &&
    execution &&
      execution.status === "completed" &&
      execution.completedAt &&
      allowedWindow > 0 && execution.completedAt.getTime() >= effectiveCutoff.getTime()
  );

  if (!isWithinWindow) {
    throw new DisputeWindowExpiredError();
  }

  const photos = input.evidencePhotoIds ?? [];
  if (photos.length > 5 || new Set(photos).size !== photos.length) {
    throw new DisputeValidationError("Invalid claim evidence");
  }
  const categories = configured.flatMap((value) => Array.isArray(value.issueCategories) ? value.issueCategories : []);
  if (configured.length > 0) {
    const normalizeCategory = (value: string) => value.trim().toLowerCase().replace(/[\s-]+/g, "_");
    if (categories.length === 0 || !input.issueCategory || !categories.some((category) => normalizeCategory(String(category)) === normalizeCategory(input.issueCategory!))) {
      throw new DisputeValidationError("This issue category is not eligible under the booking's service policy");
    }
  }
  if (configured.some((value) => value.evidenceRequired === true) && photos.length === 0) {
    throw new DisputeValidationError("This service policy requires supporting photos");
  }

  const idempotencyKey = input.idempotencyKey?.trim() || null;
  const isSameSubmission = (prior: {
    raisedBy: string;
    reason: string;
    issueCategory: string | null;
    serviceId: string | null;
    evidencePhotoIds: string[];
  } | null) => Boolean(
    prior && prior.raisedBy === customerId && prior.reason === reason &&
      prior.issueCategory === (input.issueCategory ?? null) &&
      prior.serviceId === (selectedService?.serviceId ?? null) &&
      prior.evidencePhotoIds.length === photos.length &&
      prior.evidencePhotoIds.every((id) => photos.includes(id))
  );
  if (idempotencyKey) {
    const prior = await prisma.dispute.findFirst({
      where: { bookingId, idempotencyKey },
      select: { id: true, bookingId: true, raisedBy: true, reason: true, status: true, resolutionNote: true, resolvedBy: true, resolvedAt: true, refundId: true, createdAt: true, issueCategory: true, serviceId: true, evidencePhotoIds: true }
    });
    if (prior) {
      if (!isSameSubmission(prior)) throw new DisputeConflictError("This claim submission key was already used");
      return prior;
    }
  }

  const existing = await prisma.dispute.findFirst({
    where: {
      bookingId,
      status: {
        in: ["open", "under_review", "action_required", "approved", "refund_pending", "resolved_rework"]
      }
    },
    select: {
      id: true
    }
  });

  if (existing) {
    throw new DisputeConflictError();
  }

  const referenceCode = `CL-${randomUUID().slice(0, 12).toUpperCase()}`;
  let dispute: DisputeRecord;
  try {
    dispute = await prisma.$transaction(async (tx) => {
    if (photos.length > 0) {
      const attached = await tx.bookingDiagnosticPhoto.updateMany({
        where: {
          id: { in: photos },
          uploadedById: customerId,
          bookingId: null,
          publicId: { not: { startsWith: "reservation:" } },
          expiresAt: { gt: new Date() }
        },
        data: { bookingId, expiresAt: null }
      });
      if (attached.count !== photos.length) throw new DisputeValidationError("One or more evidence photos are not attached to this booking");
    }
    const created = await tx.dispute.create({
      data: {
        bookingId,
        raisedBy: customerId,
        reason,
        status: "open",
        issueCategory: input.issueCategory ?? null,
        serviceId: selectedService?.serviceId ?? null,
        evidencePhotoIds: photos,
        idempotencyKey,
        referenceCode
      }
    });
    await tx.disputeEvent.create({
      data: {
        disputeId: created.id,
        actorId: customerId,
        actorRole: "CUSTOMER",
        type: "submitted",
        message: reason,
        visibility: "CUSTOMER",
        idempotencyKey
      }
    });
      return created;
    });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      if (idempotencyKey) {
        const prior = await prisma.dispute.findFirst({
          where: { bookingId, idempotencyKey },
          select: { id: true, bookingId: true, raisedBy: true, reason: true, status: true, resolutionNote: true, resolvedBy: true, resolvedAt: true, refundId: true, createdAt: true, issueCategory: true, serviceId: true, evidencePhotoIds: true }
        });
        if (isSameSubmission(prior)) return prior!;
      }
      throw new DisputeConflictError("A claim for this booking has already been submitted");
    }
    throw error;
  }

  await notifyAdminsOfDispute(dispute);
  await notifyClaimParties(dispute.id, "submitted", "A service claim was submitted and is ready for review.", dispute.id);

  return dispute;
}

export async function getCustomerDispute(bookingId: string, customerId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      customerId: true,
      status: true,
      services: {
        select: {
          id: true,
          serviceId: true,
          service: { select: { name: true } },
          guaranteePolicySnapshot: true
        }
      },
      jobExecution: { select: { completedAt: true, status: true } }
    }
  });
  if (!booking) {
    throw new BookingNotFoundError();
  }
  if (booking.customerId !== customerId) {
    throw new DisputeAccessError();
  }

  const dispute = await prisma.dispute.findFirst({
    where: { bookingId },
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      bookingId: true,
      serviceId: true,
      reason: true,
      issueCategory: true,
      referenceCode: true,
      evidencePhotoIds: true,
      status: true,
      resolutionNote: true,
      createdAt: true,
      resolvedAt: true,
      refundId: true,
      remedyType: true,
      remedyStatus: true,
      reworkProposedAt: true,
      reworkScheduledAt: true,
      reworkCompletedAt: true,
      customerConfirmedAt: true,
      followUpCount: true
    }
  });
  const history = dispute ? await prisma.disputeEvent.findMany({
    where: { disputeId: dispute.id, visibility: { in: ["CUSTOMER", "PARTNER"] } },
    orderBy: { createdAt: "asc" },
    select: { type: true, message: true, createdAt: true, actorRole: true }
  }) : [];
  const serviceOptions: Array<{
    bookingServiceId: string;
    serviceId: string | null;
    serviceName: string;
    policy: Prisma.JsonValue | null;
  }> = (booking.services ?? []).flatMap((item: {
    id: string;
    serviceId: string | null;
    service: { name: string } | null;
    guaranteePolicySnapshot: Prisma.JsonValue | null;
  }) => item.serviceId !== null || item.guaranteePolicySnapshot !== null ? [{
    bookingServiceId: item.id,
    serviceId: item.serviceId,
    serviceName: item.service?.name ?? "Removed service",
    policy: item.guaranteePolicySnapshot && typeof item.guaranteePolicySnapshot === "object" && !Array.isArray(item.guaranteePolicySnapshot)
      ? item.guaranteePolicySnapshot
      : null
  }] : []);
  const snapshots: Prisma.JsonObject[] = serviceOptions
    .map((item) => item.policy)
    .filter((value: Prisma.JsonValue | null): value is Prisma.JsonObject => Boolean(value && typeof value === "object" && !Array.isArray(value)));
  const bookedSnapshots: Prisma.JsonObject[] = (booking.services ?? [])
    .map((item: { guaranteePolicySnapshot: Prisma.JsonValue | null }) => item.guaranteePolicySnapshot)
    .filter((value: Prisma.JsonValue | null): value is Prisma.JsonObject => Boolean(value && typeof value === "object" && !Array.isArray(value)));
  const activePolicy = dispute?.serviceId
    ? serviceOptions.find((item) => item.serviceId === dispute.serviceId)?.policy
    : null;
  const policy = activePolicy && typeof activePolicy === "object" && "enabled" in activePolicy && activePolicy.enabled === true
    ? activePolicy
    : bookedSnapshots.find((item) => item.enabled === true) ?? null;
  const legacyWindow = !bookedSnapshots.some((snapshot) => snapshot.enabled === true);
  const completedAt = booking.jobExecution?.completedAt;
  const windowDays = Number(policy?.claimWindowDays ?? (legacyWindow ? 2 : 0));
  const hasActiveClaim = Boolean(dispute && [
    "open",
    "under_review",
    "action_required",
    "approved",
    "refund_pending",
    "resolved_rework"
  ].includes(dispute.status));
  const canSubmit = Boolean(
    !hasActiveClaim &&
    booking.status === BookingStatus.COMPLETED && booking.jobExecution?.status === "completed" && completedAt && windowDays > 0 &&
    completedAt.getTime() + windowDays * 24 * 60 * 60 * 1000 >= Date.now()
  );
  return { dispute: dispute ? { ...dispute, history } : null, policy, serviceOptions, canSubmit, legacyWindow };
}

export async function getWorkerDispute(bookingId: string, workerUserId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: { worker: { select: { userId: true } } }
  });
  if (!booking) throw new BookingNotFoundError();
  if (booking.worker?.userId !== workerUserId) throw new DisputeAccessError();
  return prisma.dispute.findFirst({
    where: { bookingId },
    orderBy: { createdAt: "desc" },
    include: { history: { where: { visibility: { in: ["CUSTOMER", "PARTNER"] } }, orderBy: { createdAt: "asc" } } }
  });
}

export async function addDisputeMessage(input: {
  bookingId: string; userId: string; role: "CUSTOMER" | "WORKER"; message: string; idempotencyKey: string;
}) {
  const dispute = await prisma.dispute.findFirst({
    where: { bookingId: input.bookingId },
    orderBy: { createdAt: "desc" },
    include: { booking: { select: { customerId: true, worker: { select: { userId: true } } } } }
  });
  if (!dispute) throw new DisputeNotFoundError();
  const allowed = input.role === "CUSTOMER"
    ? dispute.booking.customerId === input.userId
    : dispute.booking.worker?.userId === input.userId;
  if (!allowed) throw new DisputeAccessError();
  if (["resolved_rejected", "resolved_refund", "closed"].includes(dispute.status)) {
    throw new DisputeConflictError("This claim is closed to new messages");
  }
  const key = input.idempotencyKey.trim();
  const expectedType = input.role === "WORKER" ? "partner_response" : "customer_response";
  const prior = await findClaimEventByKey(dispute.id, key);
  if (prior) {
    if (prior.actorId !== input.userId || prior.message !== input.message || prior.type !== expectedType) {
      throw new DisputeConflictError("This response key was already used");
    }
    return prior;
  }
  let event: Awaited<ReturnType<typeof prisma.disputeEvent.create>>;
  try {
    event = await prisma.$transaction(async (tx) => {
      if (input.role === "CUSTOMER" && dispute.status === "action_required") {
        const resumed = await tx.dispute.updateMany({
          where: { id: dispute.id, status: "action_required" },
          data: { status: "under_review" }
        });
        if (resumed.count !== 1) throw new DisputeConflictError("The claim changed; refresh and try again");
      }
      return tx.disputeEvent.create({
        data: {
          disputeId: dispute.id,
          actorId: input.userId,
          actorRole: input.role,
          type: expectedType,
          message: input.message,
          visibility: "CUSTOMER",
          idempotencyKey: key
        }
      });
    });
  } catch (error) {
    if (!isUniqueConstraintError(error)) throw error;
    const raced = await findClaimEventByKey(dispute.id, key);
    if (raced?.actorId === input.userId && raced.message === input.message && raced.type === expectedType) return raced;
    throw new DisputeConflictError("This response key was already used");
  }
  await notifyClaimParties(dispute.id, event.type, input.role === "WORKER"
    ? "The Partner responded to your claim."
    : "The Customer added information to the claim.", event.id);
  return event;
}

export async function proposeClaimReworkAppointment(input: {
  bookingId: string; workerUserId: string; proposedAt: Date; message?: string; idempotencyKey: string;
}) {
  const dispute = await getWorkerDispute(input.bookingId, input.workerUserId);
  if (!dispute) throw new DisputeNotFoundError();
  const key = input.idempotencyKey.trim();
  const prior = await prisma.disputeEvent.findFirst({
    where: { disputeId: dispute.id, idempotencyKey: key },
    select: { id: true, actorId: true, type: true, metadata: true }
  });
  if (prior) {
    const priorProposedAt = (prior.metadata as { proposedAt?: string } | null)?.proposedAt;
    if (prior.actorId !== input.workerUserId || prior.type !== "rework_proposed" || priorProposedAt !== input.proposedAt.toISOString()) {
      throw new DisputeConflictError("This appointment proposal key was already used");
    }
    return getDisputeForResolution(dispute.id, { includeInternal: false });
  }
  if (dispute.status !== "approved" || dispute.remedyStatus !== "awaiting_partner_proposal" || !["REWORK", "REVISIT"].includes(dispute.remedyType ?? "")) {
    throw new DisputeConflictError("This claim is not waiting for a Partner appointment proposal");
  }
  try {
    await assertAssignedPartnerAvailableForRemedy(input.bookingId, input.proposedAt);
  } catch (error) {
    if (error instanceof MatchingError) throw new DisputeConflictError(error.message);
    throw error;
  }
  let event: { id: string };
  try {
    event = await prisma.$transaction(async (tx) => {
    const changed = await tx.dispute.updateMany({
      where: { id: dispute.id, status: "approved", remedyStatus: "awaiting_partner_proposal" },
      data: { remedyStatus: "awaiting_admin_schedule", reworkProposedAt: input.proposedAt }
    });
    if (changed.count !== 1) throw new DisputeConflictError("The claim changed; refresh and try again");
      return tx.disputeEvent.create({
      data: { disputeId: dispute.id, actorId: input.workerUserId, actorRole: "WORKER", type: "rework_proposed", message: input.message?.trim() || "Partner proposed a corrective-work appointment.", visibility: "CUSTOMER", metadata: { proposedAt: input.proposedAt.toISOString() }, idempotencyKey: key }
    });
    });
  } catch (error) {
    if (!isUniqueConstraintError(error)) throw error;
    const raced = await prisma.disputeEvent.findFirst({ where: { disputeId: dispute.id, idempotencyKey: key }, select: { actorId: true, type: true, metadata: true } });
    const proposedAt = (raced?.metadata as { proposedAt?: string } | null)?.proposedAt;
    if (raced?.actorId === input.workerUserId && raced.type === "rework_proposed" && proposedAt === input.proposedAt.toISOString()) return getDisputeForResolution(dispute.id, { includeInternal: false });
    throw new DisputeConflictError("This appointment proposal key was already used");
  }
  await notifyAdminsOfClaimUpdate(dispute.id, "A Partner proposed a corrective-work appointment.", event.id);
  await notifyClaimParties(dispute.id, "rework_proposed", "The Partner proposed a corrective-work appointment for Admin review.", event.id);
  return getDisputeForResolution(dispute.id, { includeInternal: false });
}

export async function completeClaimRework(input: {
  bookingId: string; workerUserId: string; message: string; idempotencyKey: string;
}) {
  const dispute = await getWorkerDispute(input.bookingId, input.workerUserId);
  if (!dispute) throw new DisputeNotFoundError();
  const key = input.idempotencyKey.trim();
  const prior = await prisma.disputeEvent.findFirst({
    where: { disputeId: dispute.id, idempotencyKey: key },
    select: { id: true, actorId: true, type: true, message: true }
  });
  if (prior) {
    if (prior.actorId !== input.workerUserId || prior.type !== "rework_completed" || prior.message !== input.message.trim()) {
      throw new DisputeConflictError("This completion key was already used");
    }
    return getDisputeForResolution(dispute.id, { includeInternal: false });
  }
  if (dispute.status !== "approved" || dispute.remedyStatus !== "scheduled" || !dispute.reworkScheduledAt) {
    throw new DisputeConflictError("Corrective work must be scheduled before it can be completed");
  }
  if (dispute.reworkScheduledAt.getTime() > Date.now()) {
    throw new DisputeConflictError("The scheduled appointment has not started yet");
  }
  const event = await prisma.$transaction(async (tx) => {
    const changed = await tx.dispute.updateMany({
      where: { id: dispute.id, status: "approved", remedyStatus: "scheduled", reworkScheduledAt: { lte: new Date() } },
      data: { status: "resolved_rework", remedyStatus: "completed", reworkCompletedAt: new Date(), resolvedAt: new Date(), resolutionNote: input.message.trim() }
    });
    if (changed.count !== 1) throw new DisputeConflictError("The corrective-work state changed; refresh and try again");
    return tx.disputeEvent.create({
      data: { disputeId: dispute.id, actorId: input.workerUserId, actorRole: "WORKER", type: "rework_completed", message: input.message.trim(), visibility: "CUSTOMER", idempotencyKey: key }
    });
  });
  await notifyClaimParties(dispute.id, "rework_completed", "The Partner reported the corrective work complete. Please confirm or request follow-up.", event.id);
  return getDisputeForResolution(dispute.id, { includeInternal: false });
}

export async function confirmClaimResolution(input: {
  bookingId: string; customerId: string; confirmed: boolean; message?: string; idempotencyKey: string;
}) {
  const dispute = await prisma.dispute.findFirst({
    where: { bookingId: input.bookingId },
    orderBy: { createdAt: "desc" },
    include: { booking: { select: { customerId: true } } }
  });
  if (!dispute) throw new DisputeNotFoundError();
  if (dispute.booking.customerId !== input.customerId) throw new DisputeAccessError();
  const key = input.idempotencyKey.trim();
  const prior = await prisma.disputeEvent.findFirst({
    where: { disputeId: dispute.id, idempotencyKey: key },
    select: { id: true, actorId: true, type: true, message: true }
  });
  if (prior) {
    const expectedType = input.confirmed ? "resolution_confirmed" : "follow_up_requested";
    if (prior.actorId !== input.customerId || prior.type !== expectedType || prior.message !== (input.message?.trim() || null)) {
      throw new DisputeConflictError("This confirmation key was already used");
    }
    return getDisputeForResolution(dispute.id, { includeInternal: false });
  }
  if (dispute.status !== "resolved_rework" && dispute.status !== "resolved_refund") {
    throw new DisputeConflictError("There is no completed remedy to confirm");
  }
  if (!input.confirmed && dispute.status !== "resolved_rework") {
    throw new DisputeConflictError("A completed refund cannot be reopened as corrective work");
  }
  if (!input.confirmed && dispute.followUpCount >= 1) {
    throw new DisputeConflictError("The permitted follow-up has already been used");
  }
  const nextStatus = input.confirmed ? "closed" : "under_review";
  const event = await prisma.$transaction(async (tx) => {
    const changed = await tx.dispute.updateMany({
      where: { id: dispute.id, status: dispute.status, followUpCount: dispute.followUpCount },
      data: {
        status: nextStatus,
        customerConfirmedAt: input.confirmed ? new Date() : null,
        remedyStatus: input.confirmed ? "customer_confirmed" : "follow_up_requested",
        followUpCount: input.confirmed ? undefined : { increment: 1 },
        resolvedAt: input.confirmed ? new Date() : null,
        resolutionNote: input.message?.trim() || (input.confirmed ? "Customer confirmed the resolution." : "Customer requested a follow-up." )
      }
    });
    if (changed.count !== 1) throw new DisputeConflictError("The claim changed; refresh and try again");
    return tx.disputeEvent.create({
      data: { disputeId: dispute.id, actorId: input.customerId, actorRole: "CUSTOMER", type: input.confirmed ? "resolution_confirmed" : "follow_up_requested", message: input.message?.trim() || null, visibility: "CUSTOMER", idempotencyKey: key }
    });
  });
  await notifyClaimParties(dispute.id, input.confirmed ? "resolution_confirmed" : "follow_up_requested", input.confirmed ? "The Customer confirmed the claim resolution." : "The Customer requested a follow-up review.", event.id);
  return getDisputeForResolution(dispute.id, { includeInternal: false });
}

export async function updateDisputeClaim(input: {
  disputeId: string; adminId: string; action: "request_info" | "approve_rework" | "schedule_rework" | "reject" | "close" | "internal_note"; message: string; visibility?: "CUSTOMER" | "INTERNAL"; scheduledAt?: Date;
}) {
  const visibility = input.visibility ?? (input.action === "internal_note" ? "INTERNAL" : "CUSTOMER");
  if (
    (input.action === "internal_note" && visibility !== "INTERNAL") ||
    (input.action !== "internal_note" && visibility === "INTERNAL")
  ) {
    throw new DisputeValidationError("Internal visibility is only valid for internal notes");
  }
  const dispute = await getDisputeForResolution(input.disputeId);
  const active = ["open", "under_review", "action_required", "approved"].includes(dispute.status);
  const closingCompletedRework = input.action === "close" && dispute.status === "resolved_rework";
  if (!active && !closingCompletedRework && input.action !== "internal_note") {
    throw new DisputeConflictError("This claim is already closed");
  }
  if (input.action === "approve_rework" && !["open", "under_review", "action_required"].includes(dispute.status)) {
    throw new DisputeConflictError("This claim already has an approved remedy");
  }
  if (
    input.action !== "internal_note" &&
    !closingCompletedRework &&
    ["scheduled", "completed", "customer_confirmed"].includes(dispute.remedyStatus ?? "")
  ) {
    throw new DisputeConflictError("The corrective-work appointment or resolution is already in progress");
  }
  if (input.action === "request_info" && !["open", "under_review"].includes(dispute.status)) {
    throw new DisputeConflictError(
      dispute.status === "action_required"
        ? "Additional information has already been requested"
        : "Information cannot be requested after a remedy is approved"
    );
  }
  const bookingServices = (dispute.booking.services ?? []) as ClaimBookingService[];
  const claimService = resolveClaimService(bookingServices, dispute.serviceId);
  const claimPolicy = claimService?.guaranteePolicySnapshot;
  const policy = isEnabledGuaranteePolicy(claimPolicy ?? null)
    ? claimPolicy
    : undefined;
  const remedyTypes = Array.isArray(policy?.resolutionTypes) ? policy.resolutionTypes : [];
  if (input.action === "approve_rework") {
    const resolutionTypes = policy?.resolutionTypes;
    const permitted = Array.isArray(resolutionTypes) && resolutionTypes.some(
      (value: unknown) => value === "REWORK" || value === "REVISIT"
    );
    if (!permitted) throw new DisputeConflictError("Corrective work is not a permitted remedy under this booking's policy");
    if (policy?.requiresPartnerReview === true) {
      const history = dispute.history as Array<{ type: string }>;
      const partnerHasResponded = history.some((event) => event.type === "partner_response");
      if (!partnerHasResponded) throw new DisputeConflictError("The Partner must respond before this claim can be approved");
    }
  }
  if (input.action === "schedule_rework") {
    if (dispute.status !== "approved" || dispute.remedyStatus !== "awaiting_admin_schedule" || !dispute.reworkProposedAt) {
      throw new DisputeConflictError("A Partner appointment proposal is required before scheduling corrective work");
    }
    if (!input.scheduledAt) throw new DisputeValidationError("Choose an appointment date and time");
    try {
      await assertAssignedPartnerAvailableForRemedy(dispute.bookingId, input.scheduledAt);
    } catch (error) {
      if (error instanceof MatchingError) throw new DisputeConflictError(error.message);
      throw error;
    }
  }
  const status = input.action === "request_info" ? "action_required"
    : input.action === "approve_rework" ? "approved"
    : input.action === "reject" ? "resolved_rejected"
    : input.action === "close" ? "closed"
    : undefined;
  const event = await prisma.$transaction(async (tx) => {
    if (status) {
      const updated = await tx.dispute.updateMany({
        where: { id: input.disputeId, status: dispute.status },
        data: {
          status,
          resolutionNote: visibility === "INTERNAL" ? undefined : input.message,
          ...(input.action === "approve_rework" ? {
            remedyType: remedyTypes.includes("REWORK") ? "REWORK" : "REVISIT",
            remedyStatus: "awaiting_partner_proposal"
          } : {}),
          resolvedBy: status === "resolved_rejected" || status === "closed" ? input.adminId : undefined,
          resolvedAt: status === "resolved_rejected" || status === "closed" ? new Date() : undefined
        }
      });
      if (updated.count !== 1) throw new DisputeConflictError("Claim changed; refresh and retry");
    }
    if (input.action === "schedule_rework") {
      const updated = await tx.dispute.updateMany({
        where: { id: input.disputeId, status: "approved", remedyStatus: "awaiting_admin_schedule" },
        data: { remedyStatus: "scheduled", reworkScheduledAt: input.scheduledAt }
      });
      if (updated.count !== 1) throw new DisputeConflictError("The appointment proposal changed; refresh and retry");
    }
    return tx.disputeEvent.create({
      data: {
        disputeId: input.disputeId,
        actorId: input.adminId,
        actorRole: "ADMIN",
        type: input.action,
        message: input.message,
        visibility,
        metadata: input.action === "schedule_rework" ? { scheduledAt: input.scheduledAt?.toISOString() } : undefined
      }
    });
  });
  const updated = await getDisputeForResolution(input.disputeId);
  if (visibility !== "INTERNAL" && input.action !== "internal_note") {
    await notifyClaimParties(input.disputeId, input.action, input.message || "Your claim was updated.", event.id);
  }
  return updated;
}

export async function getDisputeEvidence(disputeId: string): Promise<DisputeEvidence> {
  const dispute = await prisma.dispute.findUnique({
    where: { id: disputeId },
    include: {
      history: { orderBy: { createdAt: "asc" } },
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
          },
          services: { select: { serviceId: true, service: { select: { name: true } }, guaranteePolicySnapshot: true } },
          payments: {
            orderBy: { createdAt: "desc" },
            select: { id: true, status: true, amount: true, currency: true, createdAt: true, customQuoteRevisionId: true }
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
  const activeStatuses = ["open", "under_review", "action_required", "approved", "refund_pending", "resolved_rework"];
  const where = {
    ...(filters.status === "all"
      ? {}
      : filters.status
        ? { status: filters.status }
        : { status: { in: activeStatuses } }),
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
    items: items as OpenDisputeListItem[],
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

  if (!["open", "under_review", "action_required"].includes(dispute.status)) {
    throw new DisputeConflictError("This dispute has already been resolved");
  }

  if (resolution === "refund") {
    const services = (dispute.booking.services ?? []) as ClaimBookingService[];
    const selectedPolicy = resolveClaimService(services, dispute.serviceId)?.guaranteePolicySnapshot;
    if (selectedPolicy && typeof selectedPolicy === "object" && !Array.isArray(selectedPolicy) && selectedPolicy.enabled === true) {
      const remedies = selectedPolicy.resolutionTypes;
      if (!Array.isArray(remedies) || !remedies.includes("REFUND_REVIEW")) {
        throw new DisputeConflictError("A refund review is not permitted by the policy attached to this booking");
      }
    }

    await prisma.$transaction(async (tx) => {
      const claim = await tx.dispute.updateMany({
        where: { id: disputeId, status: { in: ["open", "under_review", "action_required"] } },
        data: { status: "refund_pending", resolutionNote: note, resolvedBy: adminId }
      });
      if (claim.count !== 1) throw new DisputeConflictError("This dispute is already being resolved");
      await tx.disputeEvent.create({
        data: { disputeId, actorId: adminId, actorRole: "ADMIN", type: "refund_approved", message: note, visibility: "CUSTOMER" }
      });
    });

    let refund: Awaited<ReturnType<typeof processRefund>>;
    try {
      const remainingOriginalCharge = await getRemainingOriginalBookingChargeAmount(dispute.bookingId);
      refund = await processRefund(dispute.bookingId, remainingOriginalCharge, note, dispute.id);
    } catch (error) {
      const providerStarted = error instanceof RefundProcessingError && error.providerRequestStarted;
      if (error instanceof RefundProcessingError && error.providerRequestStarted) {
        await prisma.$transaction(async (tx) => {
          const updated = await tx.dispute.updateMany({
            where: { id: disputeId, status: "refund_pending" },
            data: { refundId: error.refundId, resolvedAt: null }
          });
          if (updated.count === 1) await tx.disputeEvent.create({
            data: { disputeId, actorId: adminId, actorRole: "SYSTEM", type: "refund_pending", message: "The refund provider request started and is awaiting confirmation.", visibility: "CUSTOMER", metadata: { refundId: error.refundId } }
          });
        });
      } else {
        await prisma.$transaction(async (tx) => {
          const updated = await tx.dispute.updateMany({
            where: { id: disputeId, status: "refund_pending" },
            data: { status: "under_review", resolvedAt: null }
          });
          if (updated.count === 1) await tx.disputeEvent.create({
            data: { disputeId, actorId: adminId, actorRole: "SYSTEM", type: "refund_failed", message: "The refund could not be started. The claim returned to review and no refund completion is recorded.", visibility: "CUSTOMER" }
          });
        });
      }
      await notifyClaimParties(
        disputeId,
        providerStarted ? "refund_pending" : "refund_failed",
        providerStarted
          ? "The refund provider request started and is awaiting confirmation."
          : "The refund could not be started; the claim returned to review.",
        providerStarted && error instanceof RefundProcessingError ? `refund_pending:${error.refundId}` : `refund_failed:${Date.now()}`
      );
      throw error;
    }

    await prisma.dispute.updateMany({
      where: {
        id: dispute.id,
        OR: [{ refundId: null }, { refundId: refund.id }]
      },
      data: { refundId: refund.id }
    });
    const refundResultStatus = refund.status === "failed"
      ? "under_review"
      : refund.status === "processed"
        ? "resolved_refund"
        : "refund_pending";
    await prisma.$transaction(async (tx) => {
      const updated = await tx.dispute.updateMany({
        where: { id: dispute.id, status: "refund_pending" },
        data: { status: refundResultStatus, resolvedAt: refund.status === "processed" ? new Date() : null }
      });
      if (updated.count === 1) {
        await tx.disputeEvent.create({
          data: {
            disputeId: dispute.id,
            actorId: adminId,
            actorRole: "SYSTEM",
            type: refund.status === "processed" ? "refund_completed" : refund.status === "failed" ? "refund_failed" : "refund_pending",
            message: refund.status === "processed" ? "The refund provider confirmed the refund." : refund.status === "failed" ? "The refund did not complete and requires review." : "The refund is pending provider confirmation.",
            visibility: "CUSTOMER",
            metadata: { refundId: refund.id, providerStatus: refund.status }
          }
        });
      }
    });

    await notifyClaimParties(disputeId, `refund_${refund.status}`, refund.status === "processed"
      ? "The refund provider confirmed completion."
      : refund.status === "failed"
        ? "The refund could not be completed and has returned to review."
        : "The refund is waiting for provider confirmation.", `${refund.id}:${refund.status}`);

    return getDisputeForResolution(disputeId);
  }

  await prisma.$transaction(async (tx) => {
    const rejected = await tx.dispute.updateMany({
      where: { id: disputeId, status: { in: ["open", "under_review", "action_required"] } },
      data: { status: "resolved_rejected", resolutionNote: note, resolvedBy: adminId, resolvedAt: new Date() }
    });
    if (rejected.count !== 1) throw new DisputeConflictError("This dispute is already being resolved");
    await tx.disputeEvent.create({
      data: { disputeId, actorId: adminId, actorRole: "ADMIN", type: "rejected", message: note, visibility: "CUSTOMER" }
    });
  });
  await notifyClaimParties(disputeId, "rejected", note, `${disputeId}:rejected`);

  return getDisputeForResolution(disputeId);
}

export const disputeService = {
  raiseDispute,
  getCustomerDispute,
  getWorkerDispute,
  getDisputeEvidence,
  listOpenDisputes,
  resolveDispute,
  addDisputeMessage,
  updateDisputeClaim,
  proposeClaimReworkAppointment,
  completeClaimRework,
  confirmClaimResolution
};
