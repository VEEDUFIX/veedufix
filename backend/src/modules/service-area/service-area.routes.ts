import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  createServiceAreaSchema,
  listServiceAreasQuerySchema,
  serviceAreaCheckSchema,
  serviceAreaIdParamsSchema,
  updateServiceAreaSchema
} from "./service-area.schemas.js";
import {
  checkServiceAreaHandler,
  createServiceAreaHandler,
  deleteServiceAreaHandler,
  listServiceAreasHandler,
  updateServiceAreaHandler
} from "./service-area.controller.js";

export const serviceAreaRouter = Router();
export const adminServiceAreaRouter = Router();

serviceAreaRouter.get("/service-areas/check", validate(serviceAreaCheckSchema), checkServiceAreaHandler);

adminServiceAreaRouter.use(requireAuth, requireRole("ADMIN"));
adminServiceAreaRouter.get("/service-areas", validate(listServiceAreasQuerySchema), listServiceAreasHandler);
adminServiceAreaRouter.post("/service-areas", validate(createServiceAreaSchema), createServiceAreaHandler);
adminServiceAreaRouter.patch("/service-areas/:id", validate(serviceAreaIdParamsSchema), validate(updateServiceAreaSchema), updateServiceAreaHandler);
adminServiceAreaRouter.delete("/service-areas/:id", validate(serviceAreaIdParamsSchema), deleteServiceAreaHandler);
