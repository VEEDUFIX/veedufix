import { BookingStatus, Prisma } from "@prisma/client";
import { randomInt } from "crypto";
import { prisma } from "../../lib/prisma.js";
import { redis } from "../../lib/redis.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import { getTokensForUser } from "../device-token/device-token.service.js";
import { sendPushNotification } from "../../config/firebase-admin.js";
import { validateChecklistCompletion } from "../checklist/checklist.service.js";
import { isWorkerEligible } from "../worker-onboarding/worker-onboarding.service.js";
import { recordBookingTimelineEvent } from "../../lib/booking-timeline.js";
import { AppError } from "../../lib/app-error.js";

export class UnauthorizedError extends Error {
  constructor(message = "Unauthorized") {
    super(message);
    this.name = "UnauthorizedError";
  }
}

export class OtpExpiredError extends Error {
  constructor(message = "OTP expired") {
    super(message);
    this.name = "OtpExpiredError";
  }
}

export class OtpInvalidError extends Error {
  constructor(message = "Invalid OTP") {
    super(message);
    this.name = "OtpInvalidError";
  }
}

export class OtpAttemptLimitError extends Error {
  constructor(message = "Too many incorrect codes. Please request a new code later.") {
    super(message);
    this.name = "OtpAttemptLimitError";
  }
}

export class IncompleteJobError extends Error {
  missingItems: string[];
  missingPhotos: boolean;

  constructor(message: string, missingItems: string[], missingPhotos: boolean) {
    super(message);
    this.name = "IncompleteJobError";
    this.missingItems = missingItems;
    this.missingPhotos = missingPhotos;
  }
}

export class JobStateConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "JobStateConflictError";
  }
}

type JobExecutionRecord = {
  id: string;
  bookingId: string;
  status: string;
  otpStart: string | null;
  otpStartExpiresAt: Date | null;
  otpStartVerifiedAt: Date | null;
  otpEnd: string | null;
  otpEndExpiresAt: Date | null;
  otpEndVerifiedAt: Date | null;
  arrivedAt: Date | null;
  startedAt: Date | null;
  completedAt: Date | null;
  beforePhotos: string[];
  afterPhotos: string[];
  checklist: unknown | null;
  workerLat: number | null;
  workerLng: number | null;
};

type NotifyPayload = Record<string, unknown>;

type ArrivalOtpInput = {
  workerLat?: number;
  workerLng?: number;
};

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;
const OTP_ATTEMPT_WINDOW_SECONDS = 10 * 60;

function otpAttemptKey(bookingId: string, workerId: string, kind: "arrival" | "completion"): string {
  return `job-otp:attempts:${kind}:${bookingId}:${workerId}`;
}

async function checkOtpAttemptLimit(key: string): Promise<void> {
  const attempts = await redis.incr(key);
  if (attempts === 1) {
    await redis.expire(key, OTP_ATTEMPT_WINDOW_SECONDS);
  }
  if (attempts > OTP_MAX_ATTEMPTS) {
    throw new OtpAttemptLimitError();
  }
}

function now(): Date {
  return new Date();
}

function generateOtp(): string {
  return String(randomInt(1000, 10000));
}

function isExpired(expiresAt: Date | null | undefined): boolean {
  return !expiresAt || expiresAt.getTime() <= Date.now();
}

function formatNotification(event: string, payload: NotifyPayload): { title: string; body: string } {
  switch (event) {
    case "arrival_status_changed":
      return { title: "Arrival updated", body: "Your worker has arrived." };
    case "job_started":
      return { title: "Job started", body: "Your service job has started." };
    case "completion_otp_requested":
      return { title: "Completion OTP requested", body: "Your worker requested the completion OTP." };
    case "rating_requested":
      return { title: "Rate your experience", body: "Your job is complete. Please leave a rating." };
    default:
      return {
        title: event,
        body: typeof payload.message === "string" ? payload.message : event
      };
  }
}

async function notifyCustomer(customerId: string, event: string, payload: NotifyPayload): Promise<void> {
  const { title, body } = formatNotification(event, payload);

  try {
    await publishNotificationEvent({
      userId: customerId,
      title,
      body,
      type: event,
      data: payload
    });
  } catch (error) {
    logger.warn({ error, customerId, event }, "Realtime notification delivery failed");
  }

  void (async () => {
    try {
      const tokens = await getTokensForUser(customerId);
      if (tokens.length === 0) {
        return;
      }

      await sendPushNotification(tokens, title, body, payload);
    } catch (error) {
      logger.warn({ error, customerId, event }, "Push notification delivery failed");
    }
  })();
}

async function getBookingWithExecution(bookingId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      worker: {
        include: {
          user: true
        }
      },
      jobExecution: true,
      services: {
        include: {
          service: true,
          serviceSubcategory: true
        }
      }
    }
  });

  if (!booking) {
    throw AppError.notFound("Booking not found");
  }

  return booking;
}

async function ensureExecutionRow(bookingId: string): Promise<JobExecutionRecord> {
  const execution = await prisma.jobExecution.upsert({
    where: { bookingId },
    create: {
      bookingId,
      status: "assigned",
      beforePhotos: [],
      afterPhotos: []
    },
    update: {}
  });

  return execution as JobExecutionRecord;
}

async function requireWorkerBooking(bookingId: string, workerId: string) {
  const booking = await getBookingWithExecution(bookingId);

  if (booking.workerId !== workerId) {
    throw new UnauthorizedError("You are not assigned to this booking");
  }

  if (!booking.worker?.userId || !(await isWorkerEligible(booking.worker.userId))) {
    throw new UnauthorizedError("Worker profile is not approved");
  }

  const execution = (booking.jobExecution ?? (await ensureExecutionRow(bookingId))) as JobExecutionRecord;
  return { booking, execution };
}

async function requireCustomerBooking(bookingId: string, customerId: string) {
  const booking = await getBookingWithExecution(bookingId);

  if (booking.customerId !== customerId) {
    throw new UnauthorizedError("You do not own this booking");
  }

  const execution = (booking.jobExecution ?? (await ensureExecutionRow(bookingId))) as JobExecutionRecord;
  return { booking, execution };
}

function resolveServiceId(booking: Awaited<ReturnType<typeof getBookingWithExecution>>): string {
  const serviceId = booking.services.find((item: any) => item.serviceId)?.serviceId;
  if (!serviceId) {
    throw AppError.notFound("Service not found for booking");
  }

  return serviceId;
}

function mergePhotos(existing: string[], next: string[]): string[] {
  return [...existing, ...next.filter((url) => !existing.includes(url))];
}

function asJsonInput(value: unknown): Prisma.InputJsonValue {
  return value as Prisma.InputJsonValue;
}

export async function generateArrivalOtp(
  bookingId: string,
  workerId: string,
  input: ArrivalOtpInput = {}
): Promise<{ bookingId: string; status: string; otpExpiresAt: Date }> {
  const { booking, execution } = await requireWorkerBooking(bookingId, workerId);
  if (![BookingStatus.WORKER_ASSIGNED, BookingStatus.ARRIVED].includes(booking.status)) {
    throw new JobStateConflictError("Arrival can only be recorded for an assigned job");
  }
  const otpStart = generateOtp();
  const otpStartExpiresAt = new Date(Date.now() + OTP_TTL_MS);

  const arrivedAt = now();
  const updated = await prisma.$transaction(async (tx) => {
    const bookingTransition = await tx.booking.updateMany({
      where: { id: bookingId, status: { in: [BookingStatus.WORKER_ASSIGNED, BookingStatus.ARRIVED] } },
      data: { status: BookingStatus.ARRIVED }
    });
    if (bookingTransition.count !== 1) {
      throw new JobStateConflictError("This booking can no longer be marked as arrived");
    }

    return tx.jobExecution.upsert({
      where: { bookingId },
      create: {
        bookingId,
        otpStart,
        otpStartExpiresAt,
        status: "arrived",
        arrivedAt,
        startedAt: null,
        completedAt: null,
        beforePhotos: execution.beforePhotos,
        afterPhotos: execution.afterPhotos,
        ...(execution.checklist !== null && execution.checklist !== undefined
          ? { checklist: asJsonInput(execution.checklist) }
          : {}),
        workerLat: input.workerLat,
        workerLng: input.workerLng
      },
      update: {
        otpStart,
        otpStartExpiresAt,
        otpStartVerifiedAt: null,
        status: "arrived",
        arrivedAt,
        workerLat: input.workerLat,
        workerLng: input.workerLng
      }
    });
  });
  await redis.del(otpAttemptKey(bookingId, workerId, "arrival"));
  void recordBookingTimelineEvent({
    bookingId,
    status: BookingStatus.ARRIVED,
    title: "Professional arrived",
    description: "The assigned professional has reached the job location."
  });

  await notifyCustomer(booking.customerId, "arrival_status_changed", {
    bookingId,
    status: "arrived"
  });

  return {
    bookingId: updated.bookingId,
    status: updated.status,
    otpExpiresAt: updated.otpStartExpiresAt ?? otpStartExpiresAt
  };
}

export async function getArrivalOtpForCustomer(
  bookingId: string,
  customerId: string
): Promise<{ bookingId: string; otp: string; otpExpiresAt: Date }> {
  const { booking, execution } = await requireCustomerBooking(bookingId, customerId);

  if (booking.status !== BookingStatus.ARRIVED || execution.status !== "arrived" || !execution.otpStart || isExpired(execution.otpStartExpiresAt)) {
    throw new OtpExpiredError("Arrival OTP expired");
  }

  return {
    bookingId,
    otp: execution.otpStart,
    otpExpiresAt: execution.otpStartExpiresAt as Date
  };
}

export async function verifyArrivalOtp(
  bookingId: string,
  workerId: string,
  otpInput: string
): Promise<{ bookingId: string; status: string }> {
  const { booking, execution } = await requireWorkerBooking(bookingId, workerId);

  if (
    booking.status !== BookingStatus.ARRIVED || execution.status !== "arrived" ||
    execution.otpStartVerifiedAt
  ) {
    throw new JobStateConflictError("Arrival verification is no longer available for this booking");
  }

  if (!execution.otpStart || isExpired(execution.otpStartExpiresAt)) {
    throw new OtpExpiredError("Arrival OTP expired");
  }

  const attemptKey = otpAttemptKey(bookingId, workerId, "arrival");
  await checkOtpAttemptLimit(attemptKey);

  if (execution.otpStart !== otpInput.trim()) {
    throw new OtpInvalidError("Invalid arrival OTP");
  }

  const verifiedAt = now();
  await prisma.$transaction(async (tx) => {
    const bookingTransition = await tx.booking.updateMany({
      where: { id: bookingId, status: BookingStatus.ARRIVED },
      data: { status: BookingStatus.IN_PROGRESS }
    });
    const executionTransition = bookingTransition.count === 1
      ? await tx.jobExecution.updateMany({
          where: {
            bookingId,
            status: "arrived",
            otpStart: otpInput.trim(),
            otpStartVerifiedAt: null,
            otpStartExpiresAt: { gt: verifiedAt }
          },
          data: {
            otpStart: null,
            otpStartVerifiedAt: verifiedAt,
            status: "in_progress",
            startedAt: verifiedAt
          }
        })
      : { count: 0 };

    if (bookingTransition.count !== 1 || executionTransition.count !== 1) {
      throw new JobStateConflictError("Arrival code was already used or this booking has changed");
    }
  });
  await redis.del(attemptKey);
  void recordBookingTimelineEvent({
    bookingId,
    status: BookingStatus.IN_PROGRESS,
    title: "Work started",
    description: "The service is now in progress."
  });

  await notifyCustomer(booking.customerId, "job_started", { bookingId });

  return {
    bookingId,
    status: "in_progress"
  };
}

export async function uploadJobPhotos(
  bookingId: string,
  workerId: string,
  photoUrls: string[],
  type: "before" | "after"
): Promise<{ bookingId: string; type: "before" | "after"; photoUrls: string[] }> {
  const { booking, execution } = await requireWorkerBooking(bookingId, workerId);
  if (booking.status !== BookingStatus.IN_PROGRESS || execution.status !== "in_progress") {
    throw new JobStateConflictError("Job photos can only be added while work is in progress");
  }

  if (type === "after") {
    const serviceId = resolveServiceId(booking);
    if (!validateChecklistCompletion(serviceId, execution.checklist).isComplete) {
      throw new IncompleteJobError("Complete the service checklist before adding after photos", [], false);
    }
  }

  const existing = await ensureExecutionRow(bookingId);
  const nextPhotos = type === "before" ? mergePhotos(existing.beforePhotos, photoUrls) : mergePhotos(existing.afterPhotos, photoUrls);
  if (nextPhotos.length > 5) {
    throw AppError.badRequest("You can upload at most five photos for each step");
  }

  await prisma.jobExecution.update({
    where: { bookingId },
    data: type === "before" ? { beforePhotos: nextPhotos } : { afterPhotos: nextPhotos }
  });

  return {
    bookingId,
    type,
    photoUrls: nextPhotos
  };
}

export async function updateChecklist(
  bookingId: string,
  workerId: string,
  items: unknown
): Promise<{ bookingId: string; checklist: unknown }> {
  const { booking, execution } = await requireWorkerBooking(bookingId, workerId);
  if (booking.status !== BookingStatus.IN_PROGRESS || execution.status !== "in_progress") {
    throw new JobStateConflictError("The checklist can only be updated while work is in progress");
  }

  await prisma.jobExecution.upsert({
    where: { bookingId },
    create: {
      bookingId,
      beforePhotos: [],
      afterPhotos: [],
      checklist: asJsonInput(items)
    },
    update: {
      checklist: asJsonInput(items)
    }
  });

  return {
    bookingId,
    checklist: items
  };
}

export async function generateCompletionOtp(
  bookingId: string,
  workerId: string
): Promise<{ bookingId: string; status: string; otpExpiresAt: Date }> {
  const { booking, execution } = await requireWorkerBooking(bookingId, workerId);
  if (booking.status !== BookingStatus.IN_PROGRESS || execution.status !== "in_progress" || !execution.otpStartVerifiedAt) {
    throw new JobStateConflictError("Start the job with the arrival code before requesting completion");
  }
  const serviceId = resolveServiceId(booking);
  const checklistResult = validateChecklistCompletion(serviceId, execution.checklist);
  const missingPhotos = execution.beforePhotos.length === 0 || execution.afterPhotos.length === 0;

  if (missingPhotos || !checklistResult.isComplete) {
    throw new IncompleteJobError(
      "Job cannot be completed yet",
      checklistResult.missingItems,
      missingPhotos
    );
  }

  const otpEnd = generateOtp();
  const otpEndExpiresAt = new Date(Date.now() + OTP_TTL_MS);

  const updated = await prisma.jobExecution.update({
    where: { bookingId },
    data: {
      otpEnd,
      otpEndExpiresAt,
      otpEndVerifiedAt: null,
      status: "in_progress"
    }
  });
  await redis.del(otpAttemptKey(bookingId, workerId, "completion"));

  await notifyCustomer(booking.customerId, "completion_otp_requested", {
    bookingId
  });

  return {
    bookingId: updated.bookingId,
    status: updated.status,
    otpExpiresAt: updated.otpEndExpiresAt ?? otpEndExpiresAt
  };
}

export async function getCompletionOtpForCustomer(
  bookingId: string,
  customerId: string
): Promise<{ bookingId: string; otp: string; otpExpiresAt: Date }> {
  const { booking, execution } = await requireCustomerBooking(bookingId, customerId);

  if (booking.status !== BookingStatus.IN_PROGRESS || execution.status !== "in_progress" || !execution.otpEnd || isExpired(execution.otpEndExpiresAt)) {
    throw new OtpExpiredError("Completion OTP expired");
  }

  return {
    bookingId,
    otp: execution.otpEnd,
    otpExpiresAt: execution.otpEndExpiresAt as Date
  };
}

export async function verifyCompletionOtp(
  bookingId: string,
  workerId: string,
  otpInput: string
): Promise<{ bookingId: string; status: string }> {
  const { booking, execution } = await requireWorkerBooking(bookingId, workerId);

  if (booking.status !== BookingStatus.IN_PROGRESS || execution.status !== "in_progress" || !execution.otpEnd) {
    throw new JobStateConflictError("This booking is not ready for completion verification");
  }

  if (!execution.otpEnd || isExpired(execution.otpEndExpiresAt)) {
    throw new OtpExpiredError("Completion OTP expired");
  }

  const attemptKey = otpAttemptKey(bookingId, workerId, "completion");
  await checkOtpAttemptLimit(attemptKey);

  if (execution.otpEnd !== otpInput.trim()) {
    throw new OtpInvalidError("Invalid completion OTP");
  }

  const completedAt = now();
  await prisma.$transaction(async (tx) => {
    const bookingTransition = await tx.booking.updateMany({
      where: { id: bookingId, status: BookingStatus.IN_PROGRESS },
      data: { status: BookingStatus.COMPLETED }
    });
    const executionTransition = bookingTransition.count === 1
      ? await tx.jobExecution.updateMany({
          where: {
            bookingId,
            status: "in_progress",
            otpEnd: otpInput.trim(),
            otpEndVerifiedAt: null,
            otpEndExpiresAt: { gt: completedAt }
          },
          data: {
            otpEnd: null,
            otpEndVerifiedAt: completedAt,
            status: "completed",
            completedAt
          }
        })
      : { count: 0 };

    if (bookingTransition.count !== 1 || executionTransition.count !== 1) {
      throw new JobStateConflictError("Completion code was already used or this booking has changed");
    }
  });
  await redis.del(attemptKey);
  void recordBookingTimelineEvent({
    bookingId,
    status: BookingStatus.COMPLETED,
    title: "Job completed",
    description: "The service has been completed. Payment will be released to the worker in 48 hours if no dispute is raised."
  });

  await notifyCustomer(booking.customerId, "rating_requested", {
    bookingId
  });

  return {
    bookingId,
    status: "completed"
  };
}

export const jobExecutionService = {
  notifyCustomer,
  generateArrivalOtp,
  getArrivalOtpForCustomer,
  verifyArrivalOtp,
  uploadJobPhotos,
  updateChecklist,
  generateCompletionOtp,
  getCompletionOtpForCustomer,
  verifyCompletionOtp
};
