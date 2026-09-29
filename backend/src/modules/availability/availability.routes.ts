import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  listAvailabilitySchema,
  publicAvailabilityParamsSchema,
  customerScheduleSlotsSchema,
  setWeeklyAvailabilitySchema
} from "./availability.schemas.js";
import {
  getMyAvailabilityHandler,
  getPublicAvailabilityHandler,
  getCustomerScheduleSlotsHandler,
  setWeeklyAvailabilityHandler,
  toggleAvailabilityHandler
} from "./availability.controller.js";

export const availabilityRouter = Router();

availabilityRouter.get(
  "/schedule/slots",
  requireAuth,
  requireRole("CUSTOMER"),
  validate(customerScheduleSlotsSchema),
  getCustomerScheduleSlotsHandler
);

availabilityRouter.get(
  "/workers/:workerId/availability",
  validate(publicAvailabilityParamsSchema),
  getPublicAvailabilityHandler
);

// Keep authentication and role checks attached to each endpoint, including
// while worker onboarding is in progress.
availabilityRouter.post(
  "/worker/availability",
  requireAuth,
  requireRole("WORKER"),
  validate(setWeeklyAvailabilitySchema),
  setWeeklyAvailabilityHandler
);
availabilityRouter.get(
  "/worker/availability",
  requireAuth,
  requireRole("WORKER"),
  validate(listAvailabilitySchema),
  getMyAvailabilityHandler
);
availabilityRouter.patch(
  "/worker/availability",
  requireAuth,
  requireRole("WORKER"),
  toggleAvailabilityHandler
);
