import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { cancelBookingSchema } from "./cancellation.schemas.js";
import { cancelBookingHandler } from "./cancellation.controller.js";

export const cancellationRouter = Router();

const customerOrWorker = [requireAuth, requireRole("CUSTOMER", "WORKER")] as const;

cancellationRouter.post(
  "/bookings/:bookingId/cancel",
  ...customerOrWorker,
  validate(cancelBookingSchema),
  cancelBookingHandler
);

