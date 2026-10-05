import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import { getWorkerReviews, submitReview } from "./reviews.service.js";
import {
  dismissReviewReport,
  listReportedReviews,
  moderateReview,
  reportReview,
  respondToWorkerReview
} from "./reviews.service.js";
import { logger } from "../../lib/logger.js";
import { AppError } from "../../lib/app-error.js";
import { writeAuditLog } from "../../lib/audit.js";

export async function submitReviewHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const reviewerId = request.auth!.userId;
    const { bookingId, rating, comment, mediaUrls } = request.body;

    const review = await submitReview({
      bookingId,
      reviewerId,
      rating,
      comment,
      mediaUrls
    });

    response.status(201).json({ review });
  } catch (error) {
    logger.error(
      {
        errorName: error instanceof Error ? error.name : "UnknownError",
        reviewerId: request.auth!.userId,
        bookingId: request.body.bookingId
      },
      "Failed to submit review"
    );
    if (error instanceof AppError) {
      response.status(error.statusCode).json({ message: error.message });
    } else {
      response.status(500).json({ message: "Internal server error" });
    }
  }
}

export async function getWorkerReviewsHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const workerId = request.params.workerId as string;
    const page = parseInt(request.query.page as string) || 1;
    const limit = parseInt(request.query.limit as string) || 20;

    const data = await getWorkerReviews(workerId, page, limit);

    response.json(data);
  } catch (error) {
    logger.error({ error, workerId: request.params.workerId }, "Failed to get worker reviews");
    response.status(500).json({ message: "Internal server error" });
  }
}

export async function reportReviewHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const report = await reportReview(
      String(request.params.reviewId),
      request.auth!.userId,
      request.body.reason
    );
    response.status(201).json({ report });
  } catch (error) {
    if (error instanceof AppError) {
      response.status(error.statusCode).json({ message: error.message });
      return;
    }
    throw error;
  }
}

export async function listReviewReportsHandler(request: AuthenticatedRequest, response: Response) {
  const page = Number(request.query.page ?? 1);
  const pageSize = Number(request.query.pageSize ?? 20);
  const result = await listReportedReviews(page, pageSize);
  response.status(200).json(result);
}

export async function moderateReviewHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const review = await moderateReview(
      String(request.params.reviewId),
      request.body.status
    );
    void writeAuditLog({
      adminId: request.auth!.userId,
      action: request.body.status === "hidden" ? "review.hidden" : "review.restored",
      targetType: "review",
      targetId: String(request.params.reviewId)
    });
    response.status(200).json({ review });
  } catch (error) {
    if (error instanceof AppError) {
      response.status(error.statusCode).json({ message: error.message });
      return;
    }
    throw error;
  }
}

export async function dismissReviewReportHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const result = await dismissReviewReport(String(request.params.reportId));
    void writeAuditLog({
      adminId: request.auth!.userId,
      action: "review.report_dismissed",
      targetType: "review_report",
      targetId: result.id
    });
    response.status(200).json({ report: result });
  } catch (error) {
    if (error instanceof AppError) {
      response.status(error.statusCode).json({ message: error.message });
      return;
    }
    throw error;
  }
}

export async function workerReviewResponseHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const result = await respondToWorkerReview(
      String(request.params.reviewId),
      request.auth!.userId,
      request.body.response
    );
    response.status(200).json({ review: result });
  } catch (error) {
    if (error instanceof AppError) {
      response.status(error.statusCode).json({ message: error.message });
      return;
    }
    throw error;
  }
}
