import { BookingStatus, Prisma } from "@prisma/client";
import { randomInt } from "crypto";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import { getTokensForUser } from "../device-token/device-token.service.js";
import { sendPushNotification } from "../../config/firebase-admin.js";
import { validateChecklistCompletion } from "../checklist/checklist.service.js";
import { releaseWorkerPayout } from "../payout/payout.service.js";
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
  const otpStart = generateOtp();
  const otpStartExpiresAt = new Date(Date.now() + OTP_TTL_MS);

  const updated = await prisma.jobExecution.upsert({
    where: { bookingId },
    create: {
      bookingId,
      otpStart,
      otpStartExpiresAt,
      status: "arrived",
      arrivedAt: now(),
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
      arrivedAt: now(),
      workerLat: input.workerLat,
      workerLng: input.workerLng
    }
  });

  await prisma.booking.update({
    where: { id: bookingId },
    data: { status: BookingStatus.ARRIVED }
  });
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
  const { execution } = await requireCustomerBooking(bookingId, customerId);

  if (execution.status !== "arrived" || !execution.otpStart || isExpired(execution.otpStartExpiresAt)) {
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

  if (!execution.otpStart || isExpired(execution.otpStartExpiresAt)) {
    throw new OtpExpiredError("Arrival OTP expired");
  }

  if (execution.otpStart !== otpInput.trim()) {
    throw new OtpInvalidError("Invalid arrival OTP");
  }

  const updated = await prisma.jobExecution.update({
    where: { bookingId },
    data: {
      otpStartVerifiedAt: now(),
      status: "in_progress",
      startedAt: now()
    }
  });

  await prisma.booking.update({
    where: { id: bookingId },
    data: { status: BookingStatus.IN_PROGRESS }
  });
  void recordBookingTimelineEvent({
    bookingId,
    status: BookingStatus.IN_PROGRESS,
    title: "Work started",
    description: "The service is now in progress."
  });

  await notifyCustomer(booking.customerId, "job_started", { bookingId });

  return {
    bookingId: updated.bookingId,
    status: updated.status
  };
}

export async function uploadJobPhotos(
  bookingId: string,
  workerId: string,
  photoUrls: string[],
  type: "before" | "after"
): Promise<{ bookingId: string; type: "before" | "after"; photoUrls: string[] }> {
  await requireWorkerBooking(bookingId, workerId);

  const existing = await ensureExecutionRow(bookingId);
  const nextPhotos = type === "before" ? mergePhotos(existing.beforePhotos, photoUrls) : mergePhotos(existing.afterPhotos, photoUrls);

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
  await requireWorkerBooking(bookingId, workerId);

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
  const serviceId = resolveServiceId(booking);
  const checklistResult = validateChecklistCompletion(serviceId, execution.checklist);
  const missingPhotos = execution.afterPhotos.length === 0;

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
  const { execution } = await requireCustomerBooking(bookingId, customerId);

  if (execution.status !== "in_progress" || !execution.otpEnd || isExpired(execution.otpEndExpiresAt)) {
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

  if (!execution.otpEnd || isExpired(execution.otpEndExpiresAt)) {
    throw new OtpExpiredError("Completion OTP expired");
  }

  if (execution.otpEnd !== otpInput.trim()) {
    throw new OtpInvalidError("Invalid completion OTP");
  }

  const updated = await prisma.jobExecution.update({
    where: { bookingId },
    data: {
      otpEndVerifiedAt: now(),
      status: "completed",
      completedAt: now()
    }
  });

  await prisma.booking.update({
    where: { id: bookingId },
    data: { status: BookingStatus.COMPLETED }
  });
  void recordBookingTimelineEvent({
    bookingId,
    status: BookingStatus.COMPLETED,
    title: "Job completed",
    description: "The service has been completed."
  });

  await releaseWorkerPayout(bookingId);

  await notifyCustomer(booking.customerId, "rating_requested", {
    bookingId
  });

  return {
    bookingId: updated.bookingId,
    status: updated.status
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
