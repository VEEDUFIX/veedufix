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

// The handlers resolve the worker profile from the authenticated user. This
// keeps onboarding availability compatible with worker sessions issued by
// older auth deployments while still preventing access without a session.
availabilityRouter.use(requireAuth);
availabilityRouter.post("/worker/availability", validate(setWeeklyAvailabilitySchema), setWeeklyAvailabilityHandler);
availabilityRouter.get("/worker/availability", validate(listAvailabilitySchema), getMyAvailabilityHandler);
availabilityRouter.patch("/worker/availability", toggleAvailabilityHandler);
