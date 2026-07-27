import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  listAvailabilitySchema,
  publicAvailabilityParamsSchema,
  setWeeklyAvailabilitySchema
} from "./availability.schemas.js";
import {
  getMyAvailabilityHandler,
  getPublicAvailabilityHandler,
  setWeeklyAvailabilityHandler
} from "./availability.controller.js";

export const availabilityRouter = Router();

availabilityRouter.get(
  "/workers/:workerId/availability",
  validate(publicAvailabilityParamsSchema),
  getPublicAvailabilityHandler
);

availabilityRouter.use(requireAuth, requireRole("WORKER"));
availabilityRouter.post("/worker/availability", validate(setWeeklyAvailabilitySchema), setWeeklyAvailabilityHandler);
availabilityRouter.get("/worker/availability", validate(listAvailabilitySchema), getMyAvailabilityHandler);
