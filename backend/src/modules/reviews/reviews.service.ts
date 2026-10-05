import { Prisma } from "@prisma/client";
import { prisma as db } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent } from "../../lib/realtime.js";

export async function submitReview(data: {
  bookingId: string;
  reviewerId: string;
  rating: number;
  comment?: string;
  mediaUrls?: string[];
}) {
  if (!Number.isInteger(data.rating) || data.rating < 1 || data.rating > 5) {
    throw AppError.badRequest("Rating must be a whole number from 1 to 5");
  }

  const comment = data.comment?.trim();
  if (comment && comment.length > 500) {
    throw AppError.badRequest("Review comments must be 500 characters or fewer");
  }

  const booking = await db.booking.findUnique({
    where: { id: data.bookingId }
  });

  if (!booking) {
    throw AppError.notFound("Booking not found");
  }

  if (booking.customerId !== data.reviewerId) {
    throw AppError.forbidden("Not authorized to review this booking");
  }

  if (!booking.workerId) {
    throw AppError.conflict("This booking does not have an assigned worker yet");
  }

  if (booking.status !== "COMPLETED") {
    throw AppError.conflict("You can review a booking after the service is completed");
  }

  // Check if review already exists
  const existing = await db.review.findUnique({
    where: { bookingId: data.bookingId }
  });

  if (existing) {
    throw AppError.conflict("Review already submitted for this booking");
  }

  const review = await db.review.create({
    data: {
      bookingId: data.bookingId,
      reviewerId: data.reviewerId,
      workerId: booking.workerId,
      rating: data.rating,
      comment: comment || undefined,
      mediaUrls: data.mediaUrls ? data.mediaUrls : []
    }
  });

  // Calculate new average rating for the worker
  const allReviews = await db.review.findMany({
    where: { workerId: booking.workerId, moderationStatus: "published" },
    select: { rating: true }
  });

  const totalReviews = allReviews.length;
  const averageRating = (allReviews as Array<{ rating: number }>).reduce(
    (acc: number, curr: { rating: number }) => acc + curr.rating,
    0
  ) / totalReviews;

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
      where: { workerId, moderationStatus: "published" },
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
    db.review.count({ where: { workerId, moderationStatus: "published" } })
  ]);

  return { reviews, total, page, limit };
}

export async function reportReview(reviewId: string, reporterId: string, reason: string) {
  const review = await db.review.findUnique({
    where: { id: reviewId },
    select: { id: true, reviewerId: true, moderationStatus: true }
  });
  if (!review) throw AppError.notFound("Review not found");
  if (review.moderationStatus !== "published") {
    throw AppError.conflict("This review is already under moderation");
  }
  if (review.reviewerId === reporterId) {
    throw AppError.badRequest("You cannot report your own review");
  }

  try {
    return await db.reviewReport.create({
      data: { reviewId, reporterId, reason }
    });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      throw AppError.conflict("You have already reported this review");
    }
    throw error;
  }
}

export async function listReportedReviews(page = 1, pageSize = 20) {
  const where = {
    OR: [
      { status: "open" },
      { review: { moderationStatus: "hidden" } }
    ]
  };
  const [items, total] = await Promise.all([
    db.reviewReport.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * pageSize,
      take: pageSize,
      include: {
        reporter: { select: { id: true, name: true, email: true } },
        review: {
          include: {
            reviewer: { select: { id: true, name: true, email: true } },
            worker: { select: { id: true, fullName: true, displayName: true } },
            booking: { select: { id: true, code: true } }
          }
        }
      }
    }),
    db.reviewReport.count({ where })
  ]);
  return { items, total, page, pageSize };
}

export async function moderateReview(reviewId: string, status: "published" | "hidden") {
  const review = await db.review.findUnique({
    where: { id: reviewId },
    select: { id: true, workerId: true }
  });
  if (!review) throw AppError.notFound("Review not found");

  return db.$transaction(async (tx) => {
    const updated = await tx.review.update({
      where: { id: reviewId },
      data: { moderationStatus: status }
    });
    await tx.reviewReport.updateMany({
      where: { reviewId, status: "open" },
      data: { status: status === "hidden" ? "actioned" : "dismissed" }
    });

    const publishedReviews = await tx.review.findMany({
      where: { workerId: review.workerId, moderationStatus: "published" },
      select: { rating: true }
    });
    const averageRating = publishedReviews.length
      ? publishedReviews.reduce((sum, entry) => sum + entry.rating, 0) / publishedReviews.length
      : 0;
    await tx.workerProfile.update({
      where: { id: review.workerId },
      data: { averageRating: Number(averageRating.toFixed(1)) }
    });
    return updated;
  });
}

export async function dismissReviewReport(reportId: string) {
  const result = await db.reviewReport.updateMany({
    where: { id: reportId, status: "open" },
    data: { status: "dismissed" }
  });
  if (result.count !== 1) {
    throw AppError.conflict("This review report has already been handled");
  }
  return { id: reportId, status: "dismissed" as const };
}

export async function respondToWorkerReview(reviewId: string, workerUserId: string, response: string) {
  const worker = await db.workerProfile.findUnique({
    where: { userId: workerUserId },
    select: { id: true }
  });
  if (!worker) throw AppError.notFound("Worker profile not found");

  const review = await db.review.findUnique({
    where: { id: reviewId },
    select: { id: true, workerId: true, reviewerId: true, moderationStatus: true }
  });
  if (!review) throw AppError.notFound("Review not found");
  if (review.workerId !== worker.id) throw AppError.forbidden("You can only respond to reviews of your own work");
  if (review.moderationStatus !== "published") {
    throw AppError.conflict("This review is not currently visible to customers");
  }

  const updated = await db.review.updateMany({
    where: { id: reviewId, workerId: worker.id, moderationStatus: "published" },
    data: { workerResponse: response.trim(), workerResponseAt: new Date() }
  });
  if (updated.count !== 1) {
    throw AppError.conflict("This review changed while you were responding. Refresh and try again.");
  }

  const result = await db.review.findUnique({
    where: { id: reviewId },
    select: { id: true, workerResponse: true, workerResponseAt: true }
  });
  if (!result) throw AppError.notFound("Review not found");

  const title = "A professional replied to your review";
  const body = "Open the professional's profile to read their response.";
  try {
    await db.notification.create({
      data: {
        userId: review.reviewerId,
        title,
        body,
        type: "REVIEW_RESPONSE",
        data: { reviewId }
      }
    });
    await publishNotificationEvent({
      userId: review.reviewerId,
      title,
      body,
      type: "REVIEW_RESPONSE",
      data: { reviewId }
    });
  } catch (error) {
    logger.warn({ error, reviewId, userId: review.reviewerId }, "Review response notification failed");
  }

  return result;
}
