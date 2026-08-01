import { BookingStatus } from "@prisma/client";
import { prisma } from "./prisma.js";
import { logger } from "./logger.js";

export type BookingTimelineEntry = {
  id: string;
  status: BookingStatus;
  title: string;
  description: string | null;
  createdAt: Date;
};

export async function recordBookingTimelineEvent(input: {
  bookingId: string;
  status: BookingStatus;
  title: string;
  description?: string | null;
}): Promise<void> {
  try {
    await prisma.bookingTimelineEvent.create({
      data: {
        bookingId: input.bookingId,
        status: input.status,
        title: input.title,
        description: input.description ?? null
      }
    });
  } catch (error) {
    logger.error({ error, bookingId: input.bookingId, status: input.status }, "Booking timeline write failed");
  }
}

export async function getBookingTimelineEvents(bookingId: string): Promise<BookingTimelineEntry[]> {
  return prisma.bookingTimelineEvent.findMany({
    where: { bookingId },
    orderBy: { createdAt: "asc" },
    select: {
      id: true,
      status: true,
      title: true,
      description: true,
      createdAt: true
    }
  });
}
