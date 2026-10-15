import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  createServiceAreaSchema,
  createMarketSchema,
  listServiceAreasQuerySchema,
  serviceAreaCheckSchema,
  serviceAreaIdParamsSchema,
  updateWorkerServiceAreasSchema,
  workerServiceAreasParamsSchema,
  updateMarketSchema,
  updateServiceAreaSchema
} from "./service-area.schemas.js";
import {
  checkServiceAreaHandler,
  createServiceAreaHandler,
  createMarketHandler,
  deleteServiceAreaHandler,
  listServiceAreasHandler,
  listAvailableCitiesHandler,
  getWorkerServiceAreasHandler,
  updateMarketHandler,
  updateServiceAreaHandler,
  updateWorkerServiceAreasHandler
} from "./service-area.controller.js";

export const serviceAreaRouter = Router();
export const adminServiceAreaRouter = Router();

serviceAreaRouter.get("/service-areas/check", validate(serviceAreaCheckSchema), checkServiceAreaHandler);
serviceAreaRouter.get("/service-areas/cities", listAvailableCitiesHandler);

adminServiceAreaRouter.use(requireAuth, requireRole("ADMIN"));
adminServiceAreaRouter.post("/markets", validate(createMarketSchema), createMarketHandler);
adminServiceAreaRouter.patch("/markets/:id", validate(updateMarketSchema), updateMarketHandler);
adminServiceAreaRouter.get("/service-areas", validate(listServiceAreasQuerySchema), listServiceAreasHandler);
adminServiceAreaRouter.get("/workers/:workerProfileId/service-areas", validate(workerServiceAreasParamsSchema), getWorkerServiceAreasHandler);
adminServiceAreaRouter.put("/workers/:workerProfileId/service-areas", validate(updateWorkerServiceAreasSchema), updateWorkerServiceAreasHandler);
adminServiceAreaRouter.post("/service-areas", validate(createServiceAreaSchema), createServiceAreaHandler);
adminServiceAreaRouter.patch("/service-areas/:id", validate(serviceAreaIdParamsSchema), validate(updateServiceAreaSchema), updateServiceAreaHandler);
adminServiceAreaRouter.delete("/service-areas/:id", validate(serviceAreaIdParamsSchema), deleteServiceAreaHandler);
