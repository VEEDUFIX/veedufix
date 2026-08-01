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

  if (booking.status === BookingStatus.COMPLETED || booking.status === BookingStatus.REFUNDED) {
    throw new CancellationConflictError("Completed bookings cannot be cancelled");
  }

  if (booking.status === BookingStatus.CANCELLED || booking.status === BookingStatus.CANCELLED_MANUAL || booking.status === BookingStatus.CANCELLED_NO_SHOW) {
    throw new CancellationConflictError("This booking is already cancelled");
  }

  await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: BookingStatus.CANCELLED_MANUAL
    }
  });
  void recordBookingTimelineEvent({
    bookingId,
    status: BookingStatus.CANCELLED_MANUAL,
    title: "Booking cancelled",
    description: "The booking was cancelled manually."
  });

  await prisma.jobExecution.upsert({
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

  await notifyOtherParty(booking, requestedBy, reason);

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
