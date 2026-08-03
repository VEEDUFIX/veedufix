import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import {
  deleteCommissionHandler,
  getPlatformSettingsHandler,
  listCommissionsHandler,
  saveCommissionHandler,
  savePlatformSettingsHandler
} from "./platform-settings.controller.js";

export const adminPlatformSettingsRouter = Router();

adminPlatformSettingsRouter.use(requireAuth, requireRole("ADMIN"));

adminPlatformSettingsRouter.get("/", getPlatformSettingsHandler);
adminPlatformSettingsRouter.put("/", savePlatformSettingsHandler);

adminPlatformSettingsRouter.get("/commissions", listCommissionsHandler);
adminPlatformSettingsRouter.post("/commissions", saveCommissionHandler);
adminPlatformSettingsRouter.patch("/commissions/:commissionId", saveCommissionHandler);
adminPlatformSettingsRouter.delete("/commissions/:commissionId", deleteCommissionHandler);
