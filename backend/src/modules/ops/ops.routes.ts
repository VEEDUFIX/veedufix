import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { getOpsOverviewHandler } from "./ops.controller.js";
import { getOpsAlertsHandler } from "./ops.controller.js";
import { opsAlertListQuerySchema } from "./ops.schemas.js";

export const opsRouter = Router();
export const adminAlertsRouter = Router();

opsRouter.use(requireAuth, requireRole("ADMIN"));
opsRouter.get("/summary", getOpsOverviewHandler);

adminAlertsRouter.use(requireAuth, requireRole("ADMIN"));
adminAlertsRouter.get("/", validate(opsAlertListQuerySchema), getOpsAlertsHandler);
