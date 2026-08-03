import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import { getWorkerReviews, submitReview } from "./reviews.service.js";
import { logger } from "../../lib/logger.js";

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
    logger.error({ error, body: request.body }, "Failed to submit review");
    if (error instanceof Error && error.message === "Unauthorized") {
      response.status(403).json({ message: "Not authorized to review this booking" });
    } else if (error instanceof Error && error.message.includes("already submitted")) {
      response.status(409).json({ message: "Review already submitted for this booking" });
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
