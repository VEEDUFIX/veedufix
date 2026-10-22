import { Router } from "express";
import { makeAiChatLimiter } from "../../lib/rate-limit.js";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  adminAiCatalogDraftHandler,
  adminAiCatalogOptionsHandler,
  adminAiCatalogQualityHandler,
  adminAiInsightsHandler,
  adminAiSearchHandler,
  adminAiStatusHandler,
  adminAiSupportHandler
} from "./admin-ai.controller.js";
import {
  adminAiDraftRequestSchema,
  adminAiInsightsRequestSchema,
  adminAiSearchRequestSchema,
  adminAiSupportRequestSchema
} from "./admin-ai.schemas.js";

export const adminAiRouter = Router();
adminAiRouter.use(requireAuth, requireRole("ADMIN"));

const aiLimiter = makeAiChatLimiter();
adminAiRouter.get("/status", adminAiStatusHandler);
adminAiRouter.get("/catalog-options", adminAiCatalogOptionsHandler);
adminAiRouter.post("/catalog-draft", aiLimiter, validate(adminAiDraftRequestSchema), adminAiCatalogDraftHandler);
adminAiRouter.get("/catalog-quality", aiLimiter, adminAiCatalogQualityHandler);
adminAiRouter.post("/search", aiLimiter, validate(adminAiSearchRequestSchema), adminAiSearchHandler);
adminAiRouter.post("/insights", aiLimiter, validate(adminAiInsightsRequestSchema), adminAiInsightsHandler);
adminAiRouter.post("/support-assistant", aiLimiter, validate(adminAiSupportRequestSchema), adminAiSupportHandler);
