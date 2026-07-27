import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { listRefundsQuerySchema, retryRefundParamsSchema } from "./refund.schemas.js";
import { listRefundsHandler, retryRefundHandler } from "./refund.controller.js";

export const refundRouter = Router();

refundRouter.use(requireAuth, requireRole("ADMIN"));
refundRouter.get("/", validate(listRefundsQuerySchema), listRefundsHandler);
refundRouter.post("/:refundId/retry", validate(retryRefundParamsSchema), retryRefundHandler);
