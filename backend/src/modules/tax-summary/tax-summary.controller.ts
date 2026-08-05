import { type Request, type Response } from "express";
import { writeAuditLog } from "../../lib/audit.js";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  exportTaxInvoicesCsv,
  getAnnualSummary,
  getGstSummary,
  getRevenueSummary
} from "./tax-summary.service.js";

function sendError(response: Response, error: unknown): void {
  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
    return;
  }

  response.status(500).json({ message: "Unexpected error" });
}

export async function getTaxGstSummaryHandler(
  request: AuthenticatedRequest,
  response: Response
): Promise<void> {
  try {
    const summary = await getGstSummary(String(request.query.startDate), String(request.query.endDate));
    response.status(200).json({ gstSummary: summary });
  } catch (error) {
    sendError(response, error);
  }
}

export async function getTaxRevenueSummaryHandler(
  request: AuthenticatedRequest,
  response: Response
): Promise<void> {
  try {
    const summary = await getRevenueSummary(String(request.query.startDate), String(request.query.endDate));
    response.status(200).json({ revenueSummary: summary });
  } catch (error) {
    sendError(response, error);
  }
}

export async function getTaxAnnualSummaryHandler(
  request: AuthenticatedRequest,
  response: Response
): Promise<void> {
  try {
    const summary = await getAnnualSummary(String(request.query.financialYear));
    response.status(200).json({ annualSummary: summary });
  } catch (error) {
    sendError(response, error);
  }
}

export async function exportTaxSummaryCsvHandler(
  request: AuthenticatedRequest,
  response: Response
): Promise<void> {
  try {
    const adminId = request.auth?.userId;
    const csv = await exportTaxInvoicesCsv(String(request.query.startDate), String(request.query.endDate));
    if (adminId) {
      void writeAuditLog({
        adminId,
        action: "tax_summary.exported",
        targetType: "tax_summary",
        targetId: "invoices",
        note: "Tax summary CSV export",
        metadata: {
          startDate: String(request.query.startDate),
          endDate: String(request.query.endDate)
        }
      });
    }

    response.setHeader("Content-Type", "text/csv");
    response.setHeader("Content-Disposition", `attachment; filename="tax-summary-${Date.now()}.csv"`);
    response.status(200).send(csv);
  } catch (error) {
    sendError(response, error);
  }
}
