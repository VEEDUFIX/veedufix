import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { listRefundsQuerySchema, retryRefundParamsSchema } from "./refund.schemas.js";
import { listRefundsHandler, retryRefundHandler, bulkRetryRefundsHandler, exportRefundsCsvHandler } from "./refund.controller.js";

export const refundRouter = Router();

refundRouter.use(requireAuth, requireRole("ADMIN"));
refundRouter.get("/", validate(listRefundsQuerySchema), listRefundsHandler);
refundRouter.get("/export/csv", exportRefundsCsvHandler);
refundRouter.post("/bulk-retry", bulkRetryRefundsHandler);
refundRouter.post("/:refundId/retry", validate(retryRefundParamsSchema), retryRefundHandler);

