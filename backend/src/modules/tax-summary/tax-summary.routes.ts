import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  taxSummaryAnnualQuerySchema,
  taxSummaryExportQuerySchema,
  taxSummaryGstQuerySchema,
  taxSummaryRevenueQuerySchema
} from "./tax-summary.schemas.js";
import {
  exportTaxSummaryCsvHandler,
  getTaxAnnualSummaryHandler,
  getTaxGstSummaryHandler,
  getTaxRevenueSummaryHandler
} from "./tax-summary.controller.js";

export const taxSummaryRouter = Router();

taxSummaryRouter.use(requireAuth, requireRole("ADMIN"));
taxSummaryRouter.get("/gst", validate(taxSummaryGstQuerySchema), getTaxGstSummaryHandler);
taxSummaryRouter.get("/revenue", validate(taxSummaryRevenueQuerySchema), getTaxRevenueSummaryHandler);
taxSummaryRouter.get("/annual", validate(taxSummaryAnnualQuerySchema), getTaxAnnualSummaryHandler);
taxSummaryRouter.get("/export/csv", validate(taxSummaryExportQuerySchema), exportTaxSummaryCsvHandler);
