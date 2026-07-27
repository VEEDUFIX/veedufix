import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { dispatchBookingSchema, jobOfferActionSchema } from "./matching.schemas.js";
import {
  acceptJobHandler,
  dispatchBookingHandler,
  rejectJobHandler
} from "./matching.controller.js";

export const matchingRouter = Router();

matchingRouter.post(
  "/bookings/:bookingId/dispatch",
  requireAuth,
  requireRole("ADMIN"),
  validate(dispatchBookingSchema),
  dispatchBookingHandler
);

matchingRouter.post(
  "/bookings/:bookingId/accept-job",
  requireAuth,
  requireRole("WORKER"),
  validate(jobOfferActionSchema),
  acceptJobHandler
);

matchingRouter.post(
  "/bookings/:bookingId/reject-job",
  requireAuth,
  requireRole("WORKER"),
  validate(jobOfferActionSchema),
  rejectJobHandler
);

