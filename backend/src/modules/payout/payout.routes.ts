import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { listPayoutsQuerySchema, retryPayoutParamsSchema } from "./payout.schemas.js";
import { listPayoutsHandler, retryPayoutHandler } from "./payout.controller.js";

export const payoutRouter = Router();

payoutRouter.use(requireAuth, requireRole("ADMIN"));
payoutRouter.get("/", validate(listPayoutsQuerySchema), listPayoutsHandler);
payoutRouter.post("/:payoutId/retry", validate(retryPayoutParamsSchema), retryPayoutHandler);

