import { type NextFunction, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import { getAllPayouts, retryPayout, bulkRetryFailedPayouts, exportPayoutsCsv } from "./payout.service.js";
import { writeAuditLog } from "../../lib/audit.js";

function sendError(response: Response, error: unknown): void {
  if (error instanceof Error) {
    response.status(400).json({ message: "Unable to process payout request" });
    return;
  }

  response.status(500).json({ message: "Unexpected error" });
}

export async function listPayoutsHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const result = await getAllPayouts({
      status:
        typeof request.query.status === "string" &&
        ["pending", "processing", "success", "failed"].includes(request.query.status)
          ? (request.query.status as "pending" | "processing" | "success" | "failed")
          : undefined,
      page: request.query.page ? Number(request.query.page) : undefined,
      limit: request.query.limit ? Number(request.query.limit) : undefined,
      workerId: typeof request.query.workerId === "string" ? request.query.workerId : undefined
    });

    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function retryPayoutHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const adminId = request.auth!.userId;
    const result = await retryPayout(String(request.params.payoutId));
    void writeAuditLog({ adminId, action: "payout.retried", targetType: "payout", targetId: String(request.params.payoutId) });
    response.status(200).json({ payout: result });
  } catch (error) {
    sendError(response, error);
  }
}

export async function bulkRetryPayoutsHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const adminId = request.auth!.userId;
    const result = await bulkRetryFailedPayouts();
    void writeAuditLog({ adminId, action: "payout.bulk_retried", targetType: "payout", targetId: "bulk", metadata: { ...result } });
    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function exportPayoutsCsvHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const status = typeof request.query.status === "string" ? request.query.status as any : undefined;
    const csv = await exportPayoutsCsv({ status });
    response.setHeader("Content-Type", "text/csv");
    response.setHeader("Content-Disposition", `attachment; filename="payouts-${Date.now()}.csv"`);
    response.status(200).send(csv);
  } catch (error) {
    sendError(response, error);
  }
}
