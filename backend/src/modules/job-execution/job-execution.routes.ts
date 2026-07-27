import { Router, type Request, type Response, type NextFunction } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  bookingIdParamsOnlySchema,
  generateArrivalOtpSchema,
  requestCompletionOtpSchema,
  updateChecklistSchema,
  uploadJobPhotosSchema,
  verifyArrivalOtpSchema,
  verifyCompletionOtpSchema
} from "./job-execution.schemas.js";
import {
  arriveHandler,
  checklistHandler,
  getArrivalOtpHandler,
  getCompletionOtpHandler,
  photosHandler,
  requestCompletionOtpHandler,
  verifyArrivalOtpHandler,
  verifyCompletionOtpHandler
} from "./job-execution.controller.js";

export const jobExecutionRouter = Router();

const otpFetchBuckets = new Map<string, { count: number; resetAt: number }>();

function rateLimitOtpFetch(request: Request, response: Response, next: NextFunction): void {
  const bookingId = String(request.params.bookingId ?? "");
  const now = Date.now();
  const existing = otpFetchBuckets.get(bookingId);

  if (!existing || existing.resetAt <= now) {
    otpFetchBuckets.set(bookingId, { count: 1, resetAt: now + 60 * 1000 });
    next();
    return;
  }

  if (existing.count >= 5) {
    response.status(429).json({
      message: "Rate limit exceeded. Please try again later."
    });
    return;
  }

  existing.count += 1;
  next();
}

const workerOnly = [requireAuth, requireRole("WORKER")] as const;
const customerOnly = [requireAuth, requireRole("CUSTOMER")] as const;

jobExecutionRouter.post(
  "/bookings/:bookingId/arrive",
  ...workerOnly,
  validate(generateArrivalOtpSchema),
  arriveHandler
);

jobExecutionRouter.post(
  "/bookings/:bookingId/verify-arrival-otp",
  ...workerOnly,
  validate(verifyArrivalOtpSchema),
  verifyArrivalOtpHandler
);

jobExecutionRouter.get(
  "/bookings/:bookingId/arrival-otp",
  ...customerOnly,
  validate(bookingIdParamsOnlySchema),
  rateLimitOtpFetch,
  getArrivalOtpHandler
);

jobExecutionRouter.post(
  "/bookings/:bookingId/photos",
  ...workerOnly,
  validate(uploadJobPhotosSchema),
  photosHandler
);

jobExecutionRouter.patch(
  "/bookings/:bookingId/checklist",
  ...workerOnly,
  validate(updateChecklistSchema),
  checklistHandler
);

jobExecutionRouter.post(
  "/bookings/:bookingId/request-completion-otp",
  ...workerOnly,
  validate(requestCompletionOtpSchema),
  requestCompletionOtpHandler
);

jobExecutionRouter.get(
  "/bookings/:bookingId/completion-otp",
  ...customerOnly,
  validate(bookingIdParamsOnlySchema),
  rateLimitOtpFetch,
  getCompletionOtpHandler
);

jobExecutionRouter.post(
  "/bookings/:bookingId/verify-completion-otp",
  ...workerOnly,
  validate(verifyCompletionOtpSchema),
  verifyCompletionOtpHandler
);
