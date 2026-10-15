import { BookingStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import { recordBookingTimelineEvent } from "../../lib/booking-timeline.js";

export class CancellationNotFoundError extends Error {
  constructor(message = "Booking not found") {
    super(message);
    this.name = "CancellationNotFoundError";
  }
}

export class CancellationAccessError extends Error {
  constructor(message = "You cannot cancel this booking") {
    super(message);
    this.name = "CancellationAccessError";
  }
}

export class CancellationConflictError extends Error {
  constructor(message = "This booking cannot be cancelled") {
    super(message);
    this.name = "CancellationConflictError";
  }
}

type BookingForCancellation = {
  id: string;
  code: string;
  customerId: string;
  workerId: string | null;
  status: BookingStatus;
  jobExecution: {
    status: string;
  } | null;
  worker: {
    userId: string;
  } | null;
};

async function getBookingForCancellation(bookingId: string): Promise<BookingForCancellation> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      code: true,
      customerId: true,
      workerId: true,
      status: true,
      jobExecution: {
        select: {
          status: true
        }
      },
      worker: {
        select: {
          userId: true
        }
      }
    }
  });

  if (!booking) {
    throw new CancellationNotFoundError();
  }

  return booking;
}

async function notifyOtherParty(
  booking: BookingForCancellation,
  requestedBy: "customer" | "worker",
  reason: string
): Promise<void> {
  const otherUserId =
    requestedBy === "customer" ? booking.worker?.userId ?? null : booking.customerId;

  if (!otherUserId) {
    return;
  }

  await publishNotificationEvent({
    userId: otherUserId,
    title: "Booking cancelled",
    body: requestedBy === "customer"
      ? "The customer cancelled the booking."
      : "The worker cancelled the booking.",
    type: "booking_cancelled_manual",
    data: {
      bookingId: booking.id,
      bookingCode: booking.code,
      requestedBy,
      reason,
      status: "cancelled_manual"
    }
  });
}

export async function cancelBooking(
  bookingId: string,
  requestedBy: "customer" | "worker",
  requesterId: string,
  reason: string
): Promise<{
  bookingId: string;
  bookingCode: string;
  status: BookingStatus;
}> {
  const booking = await getBookingForCancellation(bookingId);

  if (requestedBy === "customer" && booking.customerId !== requesterId) {
    throw new CancellationAccessError();
  }

  if (requestedBy === "worker" && booking.worker?.userId !== requesterId) {
    throw new CancellationAccessError();
  }

  if (
    booking.status === BookingStatus.CANCELLED ||
    booking.status === BookingStatus.CANCELLED_MANUAL
  ) {
    // A retry after a successful cancellation is safe and must not repeat
    // notifications or maintenance-occurrence updates.
    return { bookingId, bookingCode: booking.code, status: booking.status };
  }

  if (
    booking.status === BookingStatus.COMPLETED ||
    booking.status === BookingStatus.REFUNDED ||
    booking.jobExecution?.status.toLowerCase() === "completed"
  ) {
    throw new CancellationConflictError("Completed bookings cannot be cancelled");
  }

  await prisma.$transaction(async (tx) => {
    const cancellation = await tx.booking.updateMany({
      where: {
        id: bookingId,
        ...(requestedBy === "customer"
          ? { customerId: requesterId }
          : { workerId: booking.workerId }),
        status: {
          notIn: [
            BookingStatus.COMPLETED,
            BookingStatus.REFUNDED,
            BookingStatus.CANCELLED,
            BookingStatus.CANCELLED_MANUAL,
            BookingStatus.CANCELLED_NO_SHOW
          ]
        }
      },
      data: {
        status: BookingStatus.CANCELLED_MANUAL
      }
    });
    if (cancellation.count !== 1) {
      throw new CancellationConflictError("Booking status changed. Refresh and try again.");
    }

    await tx.jobExecution.upsert({
      where: { bookingId },
      create: {
        bookingId,
        status: "cancelled",
        beforePhotos: [],
        afterPhotos: []
      },
      update: {
        status: "cancelled"
      }
    });
    const linkedOccurrences = await tx.maintenanceOccurrence.findMany({
      where: { bookingId, status: "BOOKING_CREATED" },
      select: { id: true, planId: true, dueAt: true, sequence: true, plan: { select: { status: true } } }
    });
    for (const occurrence of linkedOccurrences) {
      const occurrenceUpdate = await tx.maintenanceOccurrence.updateMany({
        where: { id: occurrence.id, bookingId, status: "BOOKING_CREATED" },
        data: {
          bookingId: null,
          status: occurrence.plan.status === "CANCELLED" ? "CANCELLED" : "AWAITING_CONFIRMATION",
          failureReason: ("Booking cancelled: " + reason).slice(0, 500),
          respondedAt: new Date()
        }
      });
      if (occurrenceUpdate.count === 1) {
        await tx.maintenancePlanEvent.create({
          data: {
            planId: occurrence.planId,
            action: "LINKED_BOOKING_CANCELLED",
            details: { occurrenceId: occurrence.id, bookingId, dueAt: occurrence.dueAt.toISOString(), sequence: occurrence.sequence }
          }
        });
      }
    }
  });
  try {
    await recordBookingTimelineEvent({
      bookingId,
      status: BookingStatus.CANCELLED_MANUAL,
      title: "Booking cancelled",
      description: "The booking was cancelled manually."
    });
  } catch (error) {
    logger.warn({ error, bookingId }, "Booking cancelled but timeline recording failed");
  }

  try {
    await notifyOtherParty(booking, requestedBy, reason);
  } catch (error) {
    logger.warn({ error, bookingId }, "Booking cancelled but notification delivery failed");
  }

  logger.info(
    {
      bookingId,
      bookingCode: booking.code,
      requestedBy
    },
    "Booking cancelled manually"
  );

  return {
    bookingId,
    bookingCode: booking.code,
    status: BookingStatus.CANCELLED_MANUAL
  };
}

export const cancellationService = {
  cancelBooking
};
