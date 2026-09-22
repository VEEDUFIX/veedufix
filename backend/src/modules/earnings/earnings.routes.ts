import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  workerEarningsSummaryQuerySchema,
  workerEarningsTransactionsQuerySchema
} from "./earnings.schemas.js";
import {
  exportWorkerEarningsCsvHandler,
  getWorkerEarningsSummaryHandler,
  getWorkerTransactionHistoryHandler
} from "./earnings.controller.js";

export const earningsRouter = Router();

const workerOnly = [requireAuth, requireRole("WORKER")] as const;

earningsRouter.get(
  "/worker/earnings/summary",
  ...workerOnly,
  validate(workerEarningsSummaryQuerySchema),
  getWorkerEarningsSummaryHandler
);
earningsRouter.get(
  "/worker/earnings/transactions",
  ...workerOnly,
  validate(workerEarningsTransactionsQuerySchema),
  getWorkerTransactionHistoryHandler
);
earningsRouter.get(
  "/worker/earnings/export/csv",
  ...workerOnly,
  validate(workerEarningsTransactionsQuerySchema),
  exportWorkerEarningsCsvHandler
);
