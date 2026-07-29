import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { getWorkerReviewsSchema, submitReviewSchema } from "./reviews.schemas.js";
import { getWorkerReviewsHandler, submitReviewHandler } from "./reviews.controller.js";

export const reviewsRouter = Router();

// Publicly accessible to view reviews
reviewsRouter.get("/worker/:workerId", validate(getWorkerReviewsSchema), getWorkerReviewsHandler);

// Must be authenticated to submit
reviewsRouter.post("/", requireAuth, validate(submitReviewSchema), submitReviewHandler);
