import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  getWorkerReviewsSchema,
  dismissReviewReportSchema,
  listReviewReportsSchema,
  moderateReviewSchema,
  reportReviewSchema,
  submitReviewSchema,
  workerReviewResponseSchema
} from "./reviews.schemas.js";
import {
  getWorkerReviewsHandler,
  dismissReviewReportHandler,
  listReviewReportsHandler,
  moderateReviewHandler,
  reportReviewHandler,
  submitReviewHandler,
  workerReviewResponseHandler
} from "./reviews.controller.js";

export const reviewsRouter = Router();

// Publicly accessible to view reviews
reviewsRouter.get("/worker/:workerId", validate(getWorkerReviewsSchema), getWorkerReviewsHandler);

// Must be authenticated to submit
reviewsRouter.post("/", requireAuth, validate(submitReviewSchema), submitReviewHandler);

reviewsRouter.post(
  "/:reviewId/report",
  requireAuth,
  requireRole("CUSTOMER"),
  validate(reportReviewSchema),
  reportReviewHandler
);

reviewsRouter.get(
  "/admin/reports",
  requireAuth,
  requireRole("ADMIN"),
  validate(listReviewReportsSchema),
  listReviewReportsHandler
);

reviewsRouter.patch(
  "/worker/:reviewId/response",
  requireAuth,
  requireRole("WORKER"),
  validate(workerReviewResponseSchema),
  workerReviewResponseHandler
);

reviewsRouter.patch(
  "/admin/reports/:reportId/dismiss",
  requireAuth,
  requireRole("ADMIN"),
  validate(dismissReviewReportSchema),
  dismissReviewReportHandler
);

reviewsRouter.patch(
  "/admin/:reviewId/moderation",
  requireAuth,
  requireRole("ADMIN"),
  validate(moderateReviewSchema),
  moderateReviewHandler
);
