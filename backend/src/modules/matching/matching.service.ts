import { BookingStatus, Prisma, VerificationStatus } from "@prisma/client";
import cron from "node-cron";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent, publishTrackingEvent } from "../../lib/realtime.js";

export const MAX_CONCURRENT_JOBS = 1;
const OFFER_WINDOW_MS = 90_000;
const SCHEDULED_OFFER_WINDOW_MS = 2 * 60 * 60 * 1000;
const RADIUS_STEPS_KM = [3, 6, 10] as const;
const ACTIVE_JOB_EXECUTION_STATUSES = ["assigned", "arrived", "in_progress"] as const;
const NON_ACTIVE_BOOKING_STATUSES = ["CANCELLED", "CANCELLED_MANUAL", "CANCELLED_NO_SHOW", "REFUNDED"] as const;
const DEFAULT_RATING = 4.0;
const DEFAULT_RECENCY = 0.5;

type BookingWithDispatchData = Prisma.BookingGetPayload<{
  include: {
    address: true;
    city: true;
    services: {
      include: {
        service: true;
        serviceSubcategory: true;
      };
    };
  };
}>;

type WorkerPoolCandidate = Prisma.WorkerProfileGetPayload<{
  include: {
    user: {
      select: {
        id: true;
        name: true;
        email: true;
        phone: true;
        avatarUrl: true;
      };
    };
    cityRelation: true;
    skills: {
      include: {
        category: true;
      };
    };
  };
}>;

type RankedWorker = {
  workerProfileId: string;
  userId: string;
  score: number;
  distanceKm: number;
  ratingAvg: number;
  recencyFactor: number;
};

type DispatchOutcome = "accepted" | "rejected" | "timeout";

type DispatchSession = {
  bookingId: string;
  booking: BookingWithDispatchData;
  candidates: RankedWorker[];
  currentIndex: number;
  status: "dispatching" | "assigned" | "failed";
  offerWindowMs: number;
  currentOffer?: RankedWorker;
  currentOfferId?: string;
  currentOfferExpiresAt?: Date;
  currentOutcomeResolver?: ((outcome: DispatchOutcome) => void) | null;
  timeoutHandle?: NodeJS.Timeout | null;
};

export class MatchingError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MatchingError";
  }
}

export class DispatchNotFoundError extends MatchingError {
  constructor(message = "No active dispatch found for this booking") {
    super(message);
    this.name = "DispatchNotFoundError";
  }
}

export class DispatchConflictError extends MatchingError {
  constructor(message = "This booking cannot be dispatched in its current state") {
    super(message);
    this.name = "DispatchConflictError";
  }
}

export class OfferAuthorizationError extends MatchingError {
  constructor(message = "You are not the current job-offer candidate") {
    super(message);
    this.name = "OfferAuthorizationError";
  }
}

export class OfferExpiredError extends MatchingError {
  constructor(message = "The job offer window has expired") {
    super(message);
    this.name = "OfferExpiredError";
  }
}

const dispatchSessions = new Map<string, DispatchSession>();
let expiredOfferRecoveryStarted = false;

const CITY_CENTROIDS: Record<string, { latitude: number; longitude: number }> = {
  chennai: { latitude: 13.0827, longitude: 80.2707 },
  bengaluru: { latitude: 12.9716, longitude: 77.5946 },
  hyderabad: { latitude: 17.385, longitude: 78.4867 },
  mumbai: { latitude: 19.076, longitude: 72.8777 },
  delhi: { latitude: 28.6139, longitude: 77.209 }
};

function toNumber(value: Prisma.Decimal | number | string | null | undefined): number | null {
  if (value === null || value === undefined) {
    return null;
  }

  return typeof value === "number" ? value : Number(value);
}

function degToRad(value: number): number {
  return (value * Math.PI) / 180;
}

function haversineDistanceKm(
  origin: { latitude: number; longitude: number },
  destination: { latitude: number; longitude: number }
): number {
  const earthRadiusKm = 6371;
  const deltaLat = degToRad(destination.latitude - origin.latitude);
  const deltaLng = degToRad(destination.longitude - origin.longitude);
  const lat1 = degToRad(origin.latitude);
  const lat2 = degToRad(destination.latitude);

  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.sin(deltaLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

function neutralRating(ratingAvg: Prisma.Decimal | number | null | undefined): number {
  const numeric = toNumber(ratingAvg);
  return numeric && numeric > 0 ? numeric : DEFAULT_RATING;
}

function recencyFactor(lastCompletedAt: Date | null): number {
  if (!lastCompletedAt) {
    return DEFAULT_RECENCY;
  }

  const daysSince = (Date.now() - lastCompletedAt.getTime()) / (24 * 60 * 60 * 1000);
  if (daysSince <= 1) {
    return 1;
  }
  if (daysSince >= 30) {
    return 0;
  }

  return Number((1 - daysSince / 30).toFixed(4));
}

function resolveWorkerLocation(worker: WorkerPoolCandidate): { latitude: number; longitude: number } | null {
  const latitude = toNumber(worker.latitude);
  const longitude = toNumber(worker.longitude);
  if (latitude !== null && longitude !== null) {
    return { latitude, longitude };
  }

  const cityName = worker.cityRelation?.name?.trim().toLowerCase();
  if (!cityName) {
    return null;
  }

  return CITY_CENTROIDS[cityName] ?? null;
}

function resolveBookingCategoryId(booking: BookingWithDispatchData): string {
  const categoryId =
    booking.services.find((item) => item.service?.categoryId)?.service?.categoryId ??
    booking.services.find((item) => item.serviceSubcategory?.categoryId)?.serviceSubcategory.categoryId;

  if (!categoryId) {
    throw new MatchingError("Unable to resolve booking category");
  }

  return categoryId;
}

function resolveBookingLocation(booking: BookingWithDispatchData): { latitude: number; longitude: number } {
  const latitude = toNumber(booking.address.latitude);
  const longitude = toNumber(booking.address.longitude);

  if (latitude === null || longitude === null) {
    throw new MatchingError("Booking address is missing coordinates");
  }

  return { latitude, longitude };
}

function buildLocationLabel(booking: BookingWithDispatchData): string {
  return [
    booking.address.line1,
    booking.address.landmark,
    booking.city.name,
    booking.address.pincode
  ]
    .filter(Boolean)
    .join(", ");
}

function getOfferWindowExpiresAt(offerWindowMs: number): Date {
  return new Date(Date.now() + offerWindowMs);
}

async function createDispatchOffer(
  booking: BookingWithDispatchData,
  candidate: RankedWorker,
  rank: number,
  expiresAt: Date
) {
  return prisma.dispatchOffer.create({
    data: {
      bookingId: booking.id,
      workerId: candidate.workerProfileId,
      rank,
      status: "pending",
      offeredAt: new Date(),
      expiresAt
    }
  });
}

async function updateDispatchOfferResponse(
  offerId: string,
  status: "accepted" | "rejected" | "expired"
): Promise<boolean> {
  const result = await prisma.dispatchOffer.updateMany({
    where: {
      id: offerId,
      status: "pending"
    },
    data: {
      status,
      respondedAt: new Date()
    }
  });

  return result.count > 0;
}

async function getDispatchOfferWorkerIds(bookingId: string): Promise<string[]> {
  const offers = await prisma.dispatchOffer.findMany({
    where: {
      bookingId
    },
    select: {
      workerId: true
    }
  });

  return [...new Set(offers.map((offer) => offer.workerId))];
}

async function getWorkerProfileIdByUserId(userId: string): Promise<string | null> {
  const profile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: {
      id: true
    }
  });

  return profile?.id ?? null;
}

async function getPendingDispatchOffer(bookingId: string, workerProfileId: string) {
  return prisma.dispatchOffer.findFirst({
    where: {
      bookingId,
      workerId: workerProfileId,
      status: "pending"
    },
    select: {
      id: true,
      workerId: true,
      status: true
    }
  });
}

async function expireOffer(offerId: string): Promise<void> {
  const offer = await prisma.dispatchOffer.findUnique({
    where: { id: offerId },
    select: {
      id: true,
      bookingId: true,
      workerId: true,
      status: true
    }
  });

  if (!offer || offer.status !== "pending") {
    return;
  }

  const updated = await updateDispatchOfferResponse(offerId, "expired");
  if (!updated) {
    return;
  }

  const session = dispatchSessions.get(offer.bookingId);
  if (session && session.currentOfferId === offerId && session.currentOutcomeResolver) {
    session.currentOutcomeResolver("timeout");
    session.currentOutcomeResolver = null;
    return;
  }

  const excludedWorkerIds = await getDispatchOfferWorkerIds(offer.bookingId);

  try {
    const booking = await getBookingForDispatch(offer.bookingId);
    if (booking.bookingType === "scheduled" && booking.scheduledFor) {
      await dispatchScheduledBooking(offer.bookingId, excludedWorkerIds);
    } else {
      await assignJobWithFallback(offer.bookingId, excludedWorkerIds);
    }
  } catch (error) {
    logger.warn(
      {
        error,
        bookingId: offer.bookingId,
        workerProfileId: offer.workerId,
        offerId
      },
      "Offer expiration recovery failed"
    );
  }
}

export async function checkForExpiredOffers(): Promise<{ checked: number; expired: number }> {
  const now = new Date();
  const offers = await prisma.dispatchOffer.findMany({
    where: {
      status: "pending",
      expiresAt: {
        lt: now
      }
    },
    select: {
      id: true
    }
  });

  let expired = 0;
  for (const offer of offers) {
    try {
      await expireOffer(offer.id);
      expired += 1;
    } catch (error) {
      logger.warn(
        {
          error,
          offerId: offer.id
        },
        "Expired offer recovery failed"
      );
    }
  }

  return {
    checked: offers.length,
    expired
  };
}

export function startExpiredOfferRecovery(): void {
  if (expiredOfferRecoveryStarted) {
    return;
  }

  expiredOfferRecoveryStarted = true;

  cron.schedule("*/30 * * * * *", () => {
    void checkForExpiredOffers().catch((error) => {
      logger.error({ error }, "Expired offer recovery run failed");
    });
  });

  void checkForExpiredOffers().catch((error) => {
    logger.error({ error }, "Initial expired offer recovery run failed");
  });
}

function clearDispatchTimer(session: DispatchSession): void {
  if (session.timeoutHandle) {
    clearTimeout(session.timeoutHandle);
    session.timeoutHandle = null;
  }
}

function finishDispatchSession(bookingId: string): void {
  const session = dispatchSessions.get(bookingId);
  if (session) {
    clearDispatchTimer(session);
  }
  dispatchSessions.delete(bookingId);
}

async function notifyAdmins(title: string, body: string, data: Record<string, unknown>) {
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

async function getLastCompletionByWorker(workerIds: string[]) {
  const completedBookings = await prisma.booking.findMany({
    where: {
      workerId: { in: workerIds },
      status: BookingStatus.COMPLETED
    },
    select: {
      workerId: true,
      updatedAt: true
    },
    orderBy: {
      updatedAt: "desc"
    }
  });

  const latestByWorker = new Map<string, Date>();
  for (const booking of completedBookings) {
    if (booking.workerId && !latestByWorker.has(booking.workerId)) {
      latestByWorker.set(booking.workerId, booking.updatedAt);
    }
  }

  return latestByWorker;
}

async function getActiveJobWorkerIds(workerIds: string[]): Promise<Set<string>> {
  if (workerIds.length === 0) {
    return new Set<string>();
  }

  const activeBookings = await prisma.booking.findMany({
    where: {
      workerId: { in: workerIds }
    },
    select: {
      workerId: true,
      jobExecution: {
        select: {
          status: true
        }
      }
    }
  });

  const blocked = new Set<string>();
  for (const booking of activeBookings) {
    if (!booking.workerId || !booking.jobExecution) {
      continue;
    }

    if (ACTIVE_JOB_EXECUTION_STATUSES.includes(booking.jobExecution.status as typeof ACTIVE_JOB_EXECUTION_STATUSES[number])) {
      blocked.add(booking.workerId);
    }
  }

  return blocked;
}

function getBoundingBox(
  center: { latitude: number; longitude: number },
  radiusKm: number
): { minLatitude: number; maxLatitude: number; minLongitude: number; maxLongitude: number } {
  const latitudeDelta = radiusKm / 111.32;
  const longitudeDelta = radiusKm / (111.32 * Math.max(Math.cos((center.latitude * Math.PI) / 180), 0.01));

  return {
    minLatitude: center.latitude - latitudeDelta,
    maxLatitude: center.latitude + latitudeDelta,
    minLongitude: center.longitude - longitudeDelta,
    maxLongitude: center.longitude + longitudeDelta
  };
}

async function filterWorkersAvailableAt(workers: WorkerPoolCandidate[], dateTime: Date): Promise<WorkerPoolCandidate[]> {
  if (workers.length === 0) {
    return [];
  }

  const workerIds = workers.map((worker) => worker.id);
  const dayOfWeek = dateTime.getDay();
  const minuteOfDay = dateTime.getHours() * 60 + dateTime.getMinutes();
  const windowStart = new Date(dateTime.getTime() - 30 * 60 * 1000);
  const windowEnd = new Date(dateTime.getTime() + 30 * 60 * 1000);

  const [slots, bookingConflicts] = await Promise.all([
    prisma.workerAvailability.findMany({
      where: {
        workerId: { in: workerIds },
        dayOfWeek
      },
      select: {
        workerId: true,
        startTime: true,
        endTime: true
      }
    }),
    prisma.booking.findMany({
      where: {
        workerId: { in: workerIds },
        bookingType: "scheduled",
        scheduledFor: {
          gte: windowStart,
          lte: windowEnd
        },
        status: {
          notIn: [...NON_ACTIVE_BOOKING_STATUSES]
        }
      },
      select: {
        workerId: true
      }
    })
  ]);

  const slotsByWorker = new Map<string, Array<{ startTime: string; endTime: string }>>();
  for (const slot of slots) {
    const workerSlots = slotsByWorker.get(slot.workerId) ?? [];
    workerSlots.push({ startTime: slot.startTime, endTime: slot.endTime });
    slotsByWorker.set(slot.workerId, workerSlots);
  }

  const blockedWorkers = new Set(
    bookingConflicts.map((booking) => booking.workerId).filter((workerId): workerId is string => Boolean(workerId))
  );

  return workers.filter((worker) => {
    if (blockedWorkers.has(worker.id)) {
      return false;
    }

    const workerSlots = slotsByWorker.get(worker.id) ?? [];
    return workerSlots.some((slot) => {
      const [startHour, startMinute] = slot.startTime.split(":").map(Number);
      const [endHour, endMinute] = slot.endTime.split(":").map(Number);
      const startMinutes = startHour * 60 + startMinute;
      const endMinutes = endHour * 60 + endMinute;
      return minuteOfDay >= startMinutes && minuteOfDay < endMinutes;
    });
  });
}

async function getBookingForDispatch(bookingId: string): Promise<BookingWithDispatchData> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      address: true,
      city: true,
      services: {
        include: {
          service: true,
          serviceSubcategory: true
        }
      }
    }
  });

  if (!booking) {
    throw new MatchingError("Booking not found");
  }

  return booking;
}

async function getCandidateWorkers(
  booking: BookingWithDispatchData,
  excludeWorkerIds: string[] = [],
  options: {
    includeBusyWorkers?: boolean;
  } = {}
): Promise<WorkerPoolCandidate[]> {
  const categoryId = resolveBookingCategoryId(booking);
  const excludedWorkerIds = new Set(excludeWorkerIds);
  const bookingLocation = resolveBookingLocation(booking);
  const searchBounds = getBoundingBox(bookingLocation, RADIUS_STEPS_KM[RADIUS_STEPS_KM.length - 1]);

  const workers = await prisma.workerProfile.findMany({
    where: {
      onboardingStatus: "approved",
      verificationStatus: VerificationStatus.VERIFIED,
      ...(excludedWorkerIds.size > 0
        ? {
            id: {
              notIn: [...excludedWorkerIds]
            }
          }
        : {}),
      latitude: {
        gte: searchBounds.minLatitude,
        lte: searchBounds.maxLatitude
      },
      longitude: {
        gte: searchBounds.minLongitude,
        lte: searchBounds.maxLongitude
      },
      skills: {
        some: {
          categoryId,
          verifiedByAdmin: true
        }
      }
    },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          avatarUrl: true
        }
      },
      cityRelation: true,
      skills: {
        include: {
          category: true
        }
      }
    }
  });

  const approvedEligibleWorkers = workers;

  if (options.includeBusyWorkers) {
    return approvedEligibleWorkers;
  }

  const activeJobWorkerIds = await getActiveJobWorkerIds(approvedEligibleWorkers.map((worker) => worker.id));
  return approvedEligibleWorkers.filter((worker) => !activeJobWorkerIds.has(worker.id));
}

function scoreWorker(
  worker: WorkerPoolCandidate,
  bookingLocation: { latitude: number; longitude: number },
  lastCompletedAt: Date | null
): RankedWorker | null {
  const location = resolveWorkerLocation(worker);
  if (!location) {
    return null;
  }

  const distanceKm = haversineDistanceKm(bookingLocation, location);
  const ratingAvg = neutralRating(worker.averageRating);
  const recency = recencyFactor(lastCompletedAt);
  const score =
    (1 / Math.max(distanceKm, 0.1)) * 0.4 +
    (ratingAvg / 5) * 0.4 +
    recency * 0.2;

  return {
    workerProfileId: worker.id,
    userId: worker.userId,
    score: Number(score.toFixed(6)),
    distanceKm: Number(distanceKm.toFixed(3)),
    ratingAvg: Number(ratingAvg.toFixed(2)),
    recencyFactor: Number(recency.toFixed(4))
  };
}

async function rankCandidates(
  booking: BookingWithDispatchData,
  excludeWorkerIds: string[] = [],
  options: {
    includeBusyWorkers?: boolean;
    availabilityAt?: Date;
  } = {}
): Promise<RankedWorker[]> {
  const bookingLocation = resolveBookingLocation(booking);
  const candidateWorkers = await getCandidateWorkers(booking, excludeWorkerIds, {
    includeBusyWorkers: options.includeBusyWorkers
  });
  const workers =
    options.availabilityAt && candidateWorkers.length > 0
      ? await filterWorkersAvailableAt(candidateWorkers, options.availabilityAt)
      : candidateWorkers;
  const workerIds = workers.map((worker) => worker.id);
  const lastCompletionMap = await getLastCompletionByWorker(workerIds);

  const scored = workers
    .map((worker) => scoreWorker(worker, bookingLocation, lastCompletionMap.get(worker.id) ?? null))
    .filter((item): item is RankedWorker => item !== null);

  const ranked = scored.sort((left, right) => {
    if (left.distanceKm !== right.distanceKm) {
      return left.distanceKm - right.distanceKm;
    }

    return right.score - left.score;
  });

  for (const radiusKm of RADIUS_STEPS_KM) {
    const withinRadius = ranked.filter((candidate) => candidate.distanceKm <= radiusKm);
    if (withinRadius.length > 0) {
      return withinRadius.sort((left, right) => right.score - left.score).slice(0, 5);
    }
  }

  return [];
}

async function createJobExecutionAssignment(bookingId: string, workerProfileId: string) {
  await prisma.booking.update({
    where: { id: bookingId },
    data: {
      workerId: workerProfileId,
      status: BookingStatus.WORKER_ASSIGNED
    }
  });

  await prisma.jobExecution.upsert({
    where: { bookingId },
    create: {
      bookingId,
      status: "assigned",
      beforePhotos: [],
      afterPhotos: []
    },
    update: {
      status: "assigned"
    }
  });
}

async function sendJobOffer(
  booking: BookingWithDispatchData,
  candidate: RankedWorker,
  rank: number,
  expiresAt: Date
) {
  const categoryId = resolveBookingCategoryId(booking);
  const category = await prisma.serviceCategory.findUnique({
    where: { id: categoryId },
    select: { name: true }
  });
  const categoryName = category?.name ?? "Service request";
  const offer = await createDispatchOffer(booking, candidate, rank, expiresAt);
  const scheduledTime = booking.scheduledFor ?? booking.scheduledAt;

  await publishNotificationEvent({
    userId: candidate.userId,
    title: "New job offer",
    body: `You have a new booking offer for ${categoryName}.`,
    type: "job_offer",
    data: {
      bookingId: booking.id,
      bookingCode: booking.code,
      categoryId,
      category: categoryName,
      location: buildLocationLabel(booking),
      scheduledTime: scheduledTime.toISOString(),
      expiresAt: expiresAt.toISOString(),
      workerProfileId: candidate.workerProfileId,
      score: candidate.score,
      distanceKm: candidate.distanceKm
    }
  });

  logger.info(
    {
      bookingId: booking.id,
      bookingCode: booking.code,
      workerProfileId: candidate.workerProfileId,
      userId: candidate.userId,
      score: candidate.score,
      distanceKm: candidate.distanceKm
    },
    "Job offer sent"
  );

  return offer;
}

function awaitOutcome(session: DispatchSession, offerId: string): Promise<DispatchOutcome> {
  return new Promise((resolve) => {
    session.currentOutcomeResolver = resolve;
    session.timeoutHandle = setTimeout(() => {
      void expireOffer(offerId).catch((error) => {
        logger.error({ error, bookingId: session.bookingId, offerId }, "Offer expiration failed");
        if (session.currentOutcomeResolver) {
          session.currentOutcomeResolver("timeout");
          session.currentOutcomeResolver = null;
        }
      }).finally(() => {
        session.timeoutHandle = null;
      });
    }, session.offerWindowMs);
  });
}

async function dispatchLoop(session: DispatchSession): Promise<void> {
  while (session.currentIndex < session.candidates.length) {
    const candidate = session.candidates[session.currentIndex];
    session.currentOffer = candidate;
    session.currentOfferId = undefined;
    session.currentOfferExpiresAt = undefined;
    const expiresAt = getOfferWindowExpiresAt(session.offerWindowMs);

    const offer = await sendJobOffer(session.booking, candidate, session.currentIndex + 1, expiresAt);
    session.currentOfferId = offer.id;
    session.currentOfferExpiresAt = expiresAt;
    const outcome = await awaitOutcome(session, offer.id);
    clearDispatchTimer(session);
    session.currentOutcomeResolver = null;
    session.currentOfferId = undefined;
    session.currentOfferExpiresAt = undefined;

    if (outcome === "accepted") {
      session.status = "assigned";
      logger.info(
        {
          bookingId: session.bookingId,
          workerProfileId: candidate.workerProfileId,
          userId: candidate.userId
        },
        "Job offer accepted"
      );
      finishDispatchSession(session.bookingId);
      return;
    }

    if (outcome === "rejected") {
      logger.info(
        {
          bookingId: session.bookingId,
          workerProfileId: candidate.workerProfileId,
          userId: candidate.userId
        },
        "Job offer rejected"
      );
    } else {
      logger.info(
        {
          bookingId: session.bookingId,
          workerProfileId: candidate.workerProfileId,
          userId: candidate.userId
        },
        "Job offer timed out"
      );
    }

    session.currentIndex += 1;
  }

  session.status = "failed";
  await prisma.booking.update({
    where: { id: session.bookingId },
    data: {
      status: BookingStatus.DISPATCH_FAILED
    }
  });

  await notifyAdmins(
    "Dispatch failed",
    `Manual intervention required for booking ${session.booking.code}.`,
    {
      bookingId: session.bookingId,
      bookingCode: session.booking.code,
      categoryId: resolveBookingCategoryId(session.booking),
      reason: "No worker accepted the dispatch offer",
      candidateCount: session.candidates.length
    }
  );

  logger.warn(
    {
      bookingId: session.bookingId,
      bookingCode: session.booking.code
    },
    "Dispatch failed for all candidates"
  );

  finishDispatchSession(session.bookingId);
}

function getSessionOrThrow(bookingId: string): DispatchSession {
  const session = dispatchSessions.get(bookingId);
  if (!session) {
    throw new DispatchNotFoundError();
  }

  return session;
}

function ensureCurrentOffer(session: DispatchSession, userId: string): RankedWorker {
  const current = session.currentOffer;
  if (!current) {
    throw new DispatchNotFoundError("No job offer is currently active");
  }

  if (!session.currentOutcomeResolver) {
    throw new OfferExpiredError();
  }

  if (current.userId !== userId) {
    throw new OfferAuthorizationError();
  }

  return current;
}

export async function findAvailableWorkers(
  bookingId: string,
  excludeWorkerIds: string[] = []
): Promise<RankedWorker[]> {
  const booking = await getBookingForDispatch(bookingId);
  const ranked = await rankCandidates(booking, excludeWorkerIds);

  logger.info(
    {
      bookingId,
      bookingCode: booking.code,
      categoryId: resolveBookingCategoryId(booking),
      candidateCount: ranked.length
    },
    "Available workers ranked"
  );

  return ranked;
}

export async function findAvailableWorkersForSchedule(
  bookingId: string,
  excludeWorkerIds: string[] = []
): Promise<RankedWorker[]> {
  const booking = await getBookingForDispatch(bookingId);

  if (booking.bookingType !== "scheduled" || !booking.scheduledFor) {
    throw new DispatchConflictError("This booking is not scheduled");
  }

  const ranked = await rankCandidates(booking, excludeWorkerIds, {
    includeBusyWorkers: true,
    availabilityAt: booking.scheduledFor
  });

  logger.info(
    {
      bookingId,
      bookingCode: booking.code,
      categoryId: resolveBookingCategoryId(booking),
      candidateCount: ranked.length
    },
    "Scheduled workers ranked"
  );

  return ranked;
}

async function dispatchWithFallback(
  bookingId: string,
  excludeWorkerIds: string[],
  options: {
    offerWindowMs: number;
    useScheduleAvailability?: boolean;
  }
): Promise<{
  bookingId: string;
  bookingCode: string;
  status: "dispatching" | "assigned" | "failed";
  candidates: RankedWorker[];
}> {
  const booking = await getBookingForDispatch(bookingId);

  if (
    booking.status !== BookingStatus.ACCEPTED &&
    booking.status !== BookingStatus.DISPATCH_FAILED &&
    booking.status !== BookingStatus.CANCELLED_NO_SHOW
  ) {
    throw new DispatchConflictError();
  }

  const candidates = options.useScheduleAvailability
    ? await findAvailableWorkersForSchedule(bookingId, excludeWorkerIds)
    : await findAvailableWorkers(bookingId, excludeWorkerIds);

  if (candidates.length === 0) {
    await prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: BookingStatus.DISPATCH_FAILED
      }
    });

    await notifyAdmins(
      "Dispatch failed",
      `No eligible workers were found for booking ${booking.code}.`,
      {
        bookingId: booking.id,
        bookingCode: booking.code,
        categoryId: resolveBookingCategoryId(booking),
        reason: "No eligible workers found",
        candidateCount: 0
      }
    );

    logger.warn(
      {
        bookingId,
        bookingCode: booking.code
      },
      "No eligible workers found for dispatch"
    );

    return {
      bookingId: booking.id,
      bookingCode: booking.code,
      status: "failed",
      candidates: []
    };
  }

  if (dispatchSessions.has(bookingId)) {
    const existing = dispatchSessions.get(bookingId)!;
    logger.info(
      {
        bookingId,
        bookingCode: booking.code,
        candidateCount: existing.candidates.length
      },
      "Dispatch already in progress"
    );
    return {
      bookingId,
      bookingCode: booking.code,
      status: existing.status,
      candidates: existing.candidates
    };
  }

  const session: DispatchSession = {
    bookingId,
    booking,
    candidates,
    currentIndex: 0,
    status: "dispatching",
    offerWindowMs: options.offerWindowMs
  };

  dispatchSessions.set(bookingId, session);

  void dispatchLoop(session).catch(async (error) => {
    logger.error({ error, bookingId }, "Dispatch loop failed unexpectedly");
    session.status = "failed";
    finishDispatchSession(bookingId);
    await prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: BookingStatus.DISPATCH_FAILED
      }
    });
  });

  logger.info(
    {
      bookingId,
      bookingCode: booking.code,
      candidateCount: candidates.length
    },
    "Dispatch started"
  );

  return {
    bookingId: booking.id,
    bookingCode: booking.code,
    status: "dispatching",
    candidates
  };
}

export async function assignJobWithFallback(
  bookingId: string,
  excludeWorkerIds: string[] = []
): Promise<{
  bookingId: string;
  bookingCode: string;
  status: "dispatching" | "assigned" | "failed";
  candidates: RankedWorker[];
}> {
  return dispatchWithFallback(bookingId, excludeWorkerIds, {
    offerWindowMs: OFFER_WINDOW_MS
  });
}

export async function dispatchScheduledBooking(
  bookingId: string,
  excludeWorkerIds: string[] = []
): Promise<{
  bookingId: string;
  bookingCode: string;
  status: "dispatching" | "assigned" | "failed";
  candidates: RankedWorker[];
}> {
  return dispatchWithFallback(bookingId, excludeWorkerIds, {
    offerWindowMs: SCHEDULED_OFFER_WINDOW_MS,
    useScheduleAvailability: true
  });
}

export async function dispatchBookingAfterPayment(bookingId: string) {
  const booking = await getBookingForDispatch(bookingId);

  if (booking.bookingType === "scheduled" && booking.scheduledFor) {
    return dispatchScheduledBooking(bookingId);
  }

  return assignJobWithFallback(bookingId);
}

export async function acceptJobOffer(bookingId: string, userId: string): Promise<{
  bookingId: string;
  bookingCode: string;
  workerProfileId: string;
  status: string;
}> {
  const session = dispatchSessions.get(bookingId);
  const booking = await getBookingForDispatch(bookingId);
  const workerProfileId = session?.currentOffer?.workerProfileId ?? (await getWorkerProfileIdByUserId(userId));
  if (!workerProfileId) {
    throw new OfferAuthorizationError();
  }

  if (session) {
    ensureCurrentOffer(session, userId);
  }

  const offer = session?.currentOfferId
    ? await prisma.dispatchOffer.findUnique({
        where: { id: session.currentOfferId },
        select: { id: true, status: true }
      })
    : await getPendingDispatchOffer(bookingId, workerProfileId);

  if (!offer || offer.status !== "pending") {
    throw new OfferExpiredError();
  }

  const offerUpdated = await updateDispatchOfferResponse(offer.id, "accepted");
  if (!offerUpdated) {
    throw new OfferExpiredError();
  }

  if (session) {
    clearDispatchTimer(session);
  }
  if (session?.currentOutcomeResolver) {
    session.currentOutcomeResolver("accepted");
    session.currentOutcomeResolver = null;
  }

  await createJobExecutionAssignment(bookingId, workerProfileId);

  if (session) {
    session.status = "assigned";
  }

  await publishTrackingEvent({
    bookingId,
    status: "WORKER_ASSIGNED",
    message: "Worker accepted the dispatch offer",
    actorRole: "WORKER",
    bookingCode: booking.code
  });

  logger.info(
    {
      bookingId,
      bookingCode: booking.code,
      workerProfileId,
      userId
    },
    "Job offer accepted and booking assigned"
  );

  return {
    bookingId,
    bookingCode: booking.code,
    workerProfileId,
    status: "assigned"
  };
}

export async function rejectJobOffer(bookingId: string, userId: string): Promise<{
  bookingId: string;
  bookingCode: string;
  status: string;
}> {
  const session = dispatchSessions.get(bookingId);
  const booking = await getBookingForDispatch(bookingId);
  const workerProfileId = session?.currentOffer?.workerProfileId ?? (await getWorkerProfileIdByUserId(userId));
  if (!workerProfileId) {
    throw new OfferAuthorizationError();
  }

  if (session) {
    ensureCurrentOffer(session, userId);
  }

  const offer = session?.currentOfferId
    ? await prisma.dispatchOffer.findUnique({
        where: { id: session.currentOfferId },
        select: { id: true, status: true }
      })
    : await getPendingDispatchOffer(bookingId, workerProfileId);

  if (!offer || offer.status !== "pending") {
    throw new OfferExpiredError();
  }

  const offerUpdated = await updateDispatchOfferResponse(offer.id, "rejected");
  if (!offerUpdated) {
    throw new OfferExpiredError();
  }

  if (session) {
    clearDispatchTimer(session);
  }
  if (session?.currentOutcomeResolver) {
    session.currentOutcomeResolver("rejected");
    session.currentOutcomeResolver = null;
  }

  if (!session) {
    const excludedWorkerIds = await getDispatchOfferWorkerIds(bookingId);
    try {
      await assignJobWithFallback(bookingId, excludedWorkerIds);
    } catch (error) {
      logger.warn(
        {
          error,
          bookingId,
          bookingCode: booking.code,
          workerProfileId
        },
        "Dispatch recovery after rejection failed"
      );
    }
  }

  logger.info(
    {
      bookingId,
      bookingCode: booking.code,
      workerProfileId,
      userId
    },
    "Job offer rejected by worker"
  );

  return {
    bookingId,
    bookingCode: booking.code,
    status: "rejected"
  };
}
