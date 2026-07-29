import { Router } from "express";
import { getAnalyticsTrendsHandler } from "./analytics.controller.js";
import { requireAuth, requireRole } from "../../middleware/auth.js";

const adminAnalyticsRouter = Router();

adminAnalyticsRouter.use(requireAuth);
adminAnalyticsRouter.use(requireRole("ADMIN"));

adminAnalyticsRouter.get("/trends", getAnalyticsTrendsHandler);

export { adminAnalyticsRouter };
