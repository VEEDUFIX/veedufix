import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  workerEarningsSummaryQuerySchema,
  workerEarningsTransactionsQuerySchema
} from "./earnings.schemas.js";
import {
  getWorkerEarningsSummaryHandler,
  getWorkerTransactionHistoryHandler
} from "./earnings.controller.js";

export const earningsRouter = Router();

const workerOnly = [requireAuth, requireRole("WORKER")] as const;

earningsRouter.use(...workerOnly);
earningsRouter.get("/worker/earnings/summary", validate(workerEarningsSummaryQuerySchema), getWorkerEarningsSummaryHandler);
earningsRouter.get(
  "/worker/earnings/transactions",
  validate(workerEarningsTransactionsQuerySchema),
  getWorkerTransactionHistoryHandler
);
