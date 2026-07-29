import { prisma as db } from "../../lib/prisma.js";

export async function submitReview(data: {
  bookingId: string;
  reviewerId: string;
  rating: number;
  comment?: string;
  mediaUrls?: string[];
}) {
  const booking = await db.booking.findUnique({
    where: { id: data.bookingId }
  });

  if (!booking) {
    throw new Error("Booking not found");
  }

  if (booking.customerId !== data.reviewerId) {
    throw new Error("Unauthorized");
  }

  if (!booking.workerId) {
    throw new Error("Booking has no worker assigned");
  }

  // Check if review already exists
  const existing = await db.review.findUnique({
    where: { bookingId: data.bookingId }
  });

  if (existing) {
    throw new Error("Review already submitted for this booking");
  }

  const review = await db.review.create({
    data: {
      bookingId: data.bookingId,
      reviewerId: data.reviewerId,
      workerId: booking.workerId,
      rating: data.rating,
      comment: data.comment,
      mediaUrls: data.mediaUrls ? data.mediaUrls : []
    }
  });

  // Calculate new average rating for the worker
  const allReviews = await db.review.findMany({
    where: { workerId: booking.workerId },
    select: { rating: true }
  });

  const totalReviews = allReviews.length;
  const averageRating = allReviews.reduce((acc: number, curr: { rating: number }) => acc + curr.rating, 0) / totalReviews;

  await db.workerProfile.update({
    where: { id: booking.workerId },
    data: {
      averageRating: parseFloat(averageRating.toFixed(1))
    }
  });

  return review;
}

export async function getWorkerReviews(workerId: string, page: number = 1, limit: number = 20) {
  const skip = (page - 1) * limit;

  const [reviews, total] = await Promise.all([
    db.review.findMany({
      where: { workerId },
      include: {
        reviewer: {
          select: {
            id: true,
            name: true,
            avatarUrl: true
          }
        }
      },
      orderBy: { createdAt: "desc" },
      skip,
      take: limit
    }),
    db.review.count({ where: { workerId } })
  ]);

  return { reviews, total, page, limit };
}
