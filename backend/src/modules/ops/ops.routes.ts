import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { getOpsOverviewHandler } from "./ops.controller.js";

export const opsRouter = Router();

opsRouter.use(requireAuth, requireRole("ADMIN"));
opsRouter.get("/summary", getOpsOverviewHandler);
