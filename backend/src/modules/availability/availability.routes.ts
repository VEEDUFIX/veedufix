import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  listAvailabilitySchema,
  publicAvailabilityParamsSchema,
  setWeeklyAvailabilitySchema
} from "./availability.schemas.js";
import {
  getMyAvailabilityHandler,
  getPublicAvailabilityHandler,
  setWeeklyAvailabilityHandler,
  toggleAvailabilityHandler
} from "./availability.controller.js";

export const availabilityRouter = Router();

availabilityRouter.get(
  "/workers/:workerId/availability",
  validate(publicAvailabilityParamsSchema),
  getPublicAvailabilityHandler
);

// Keep authentication attached to each endpoint so this router cannot inherit
// a role guard from another mounted route while onboarding is in progress.
availabilityRouter.post(
  "/worker/availability",
  requireAuth,
  validate(setWeeklyAvailabilitySchema),
  setWeeklyAvailabilityHandler
);
availabilityRouter.get(
  "/worker/availability",
  requireAuth,
  validate(listAvailabilitySchema),
  getMyAvailabilityHandler
);
availabilityRouter.patch("/worker/availability", requireAuth, toggleAvailabilityHandler);
