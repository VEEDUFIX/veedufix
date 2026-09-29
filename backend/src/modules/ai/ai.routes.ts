import { Router } from "express";
import { makeAiChatLimiter } from "../../lib/rate-limit.js";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { chatHandler } from "./ai.controller.js";
import { chatSchema } from "./ai.schemas.js";

export const aiRouter = Router();

aiRouter.post("/chat", requireAuth, requireRole("CUSTOMER"), validate(chatSchema), makeAiChatLimiter(), chatHandler);
