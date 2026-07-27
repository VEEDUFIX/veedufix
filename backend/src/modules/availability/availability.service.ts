import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";

export type WeeklyAvailabilitySlot = {
  dayOfWeek: number;
  startTime: string;
  endTime: string;
};

export class WorkerAvailabilityNotFoundError extends Error {
  constructor(message = "Worker not found") {
    super(message);
    this.name = "WorkerAvailabilityNotFoundError";
  }
}

const BUFFER_MINUTES = 30;
const ACTIVE_JOB_EXECUTION_STATUSES = ["assigned", "arrived", "in_progress"] as const;

function toMinutes(time: string): number {
  const [hours, minutes] = time.split(":").map(Number);
  return hours * 60 + minutes;
}

function minutesToTime(minutes: number): string {
  const safe = Math.max(0, Math.min(23 * 60 + 59, minutes));
  const hours = Math.floor(safe / 60);
  const mins = safe % 60;
  return `${String(hours).padStart(2, "0")}:${String(mins).padStart(2, "0")}`;
}

function normalizeSlots(slots: WeeklyAvailabilitySlot[]): WeeklyAvailabilitySlot[] {
  return [...slots].sort((left, right) => {
    if (left.dayOfWeek !== right.dayOfWeek) {
      return left.dayOfWeek - right.dayOfWeek;
    }

    return toMinutes(left.startTime) - toMinutes(right.startTime);
  });
}

async function requireWorker(workerId: string) {
  const worker = await prisma.workerProfile.findUnique({
    where: { id: workerId },
    select: { id: true }
  });

  if (!worker) {
    throw new WorkerAvailabilityNotFoundError();
  }

  return worker;
}

export async function getWorkerProfileIdByUserId(userId: string): Promise<string> {
  const worker = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!worker) {
    throw new WorkerAvailabilityNotFoundError("Worker profile not found");
  }

  return worker.id;
}

export async function setWeeklyAvailability(workerId: string, slots: WeeklyAvailabilitySlot[]) {
  await requireWorker(workerId);

  return prisma.$transaction(async (tx) => {
    await tx.workerAvailability.deleteMany({
      where: { workerId }
    });

    if (slots.length > 0) {
      await tx.workerAvailability.createMany({
        data: slots.map((slot) => ({
          workerId,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime
        }))
      });
    }

    const records = await tx.workerAvailability.findMany({
      where: { workerId },
      orderBy: [{ dayOfWeek: "asc" }, { startTime: "asc" }]
    });

    return records.map((slot) => ({
      dayOfWeek: slot.dayOfWeek,
      startTime: slot.startTime,
      endTime: slot.endTime
    }));
  });
}

export async function getWorkerAvailability(workerId: string) {
  await requireWorker(workerId);

  const slots = await prisma.workerAvailability.findMany({
    where: { workerId },
    orderBy: [{ dayOfWeek: "asc" }, { startTime: "asc" }]
  });

  return slots.map((slot) => ({
    dayOfWeek: slot.dayOfWeek,
    startTime: slot.startTime,
    endTime: slot.endTime
  }));
}

export async function isWorkerAvailableAt(workerId: string, dateTime: Date): Promise<boolean> {
  const dayOfWeek = dateTime.getDay();
  const minuteOfDay = dateTime.getHours() * 60 + dateTime.getMinutes();
  const slots = await prisma.workerAvailability.findMany({
    where: {
      workerId,
      dayOfWeek
    }
  });

  const inSlot = slots.some((slot) => {
    const startMinutes = toMinutes(slot.startTime);
    const endMinutes = toMinutes(slot.endTime);
    return minuteOfDay >= startMinutes && minuteOfDay < endMinutes;
  });

  if (!inSlot) {
    return false;
  }

  const windowStart = new Date(dateTime.getTime() - BUFFER_MINUTES * 60 * 1000);
  const windowEnd = new Date(dateTime.getTime() + BUFFER_MINUTES * 60 * 1000);

  const bookingConflicts = await prisma.booking.findMany({
    where: {
      workerId,
      bookingType: "scheduled",
      scheduledFor: {
        gte: windowStart,
        lte: windowEnd
      },
      status: {
        notIn: ["CANCELLED", "CANCELLED_MANUAL", "CANCELLED_NO_SHOW", "REFUNDED"]
      }
    },
    select: { id: true }
  });

  const executionConflicts =
    bookingConflicts.length === 0
      ? []
      : await prisma.jobExecution.findMany({
          where: {
            bookingId: {
              in: bookingConflicts.map((booking) => booking.id)
            },
            status: {
              in: [...ACTIVE_JOB_EXECUTION_STATUSES]
            }
          },
          select: { id: true }
        });

  return bookingConflicts.length === 0 && executionConflicts.length === 0;
}
