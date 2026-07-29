import { type Request, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import { writeAuditLog } from "../../lib/audit.js";
import {
  RefundConflictError,
  RefundNotFoundError,
  getAllRefunds,
  retryRefund,
  bulkRetryFailedRefunds,
  exportRefundsCsv
} from "./refund.service.js";

function handleRefundError(response: Response, error: unknown): boolean {
  if (error instanceof RefundNotFoundError) {
    response.status(404).json({ message: error.message });
    return true;
  }

  if (error instanceof RefundConflictError) {
    response.status(409).json({ message: error.message });
    return true;
  }

  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
    return true;
  }

  return false;
}

export async function listRefundsHandler(request: Request, response: Response): Promise<void> {
  try {
    const result = await getAllRefunds({
      status: typeof request.query.status === "string" ? (request.query.status as "pending" | "processed" | "failed") : undefined,
      workerId: typeof request.query.workerId === "string" ? request.query.workerId : undefined,
      page: typeof request.query.page === "number" ? request.query.page : Number(request.query.page ?? 1),
      pageSize:
        typeof request.query.pageSize === "number" ? request.query.pageSize : Number(request.query.pageSize ?? 20)
    });

    response.status(200).json(result);
  } catch (error) {
    if (!handleRefundError(response, error)) {
      throw error;
    }
  }
}

export async function retryRefundHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;

  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  try {
    const result = await retryRefund(String(request.params.refundId));
    void writeAuditLog({ adminId: authRequest.auth.userId, action: "refund.retried", targetType: "refund", targetId: String(request.params.refundId) });
    response.status(200).json({ refund: result });
  } catch (error) {
    if (!handleRefundError(response, error)) {
      throw error;
    }
  }
}

export async function bulkRetryRefundsHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }
  try {
    const result = await bulkRetryFailedRefunds();
    void writeAuditLog({ adminId: authRequest.auth.userId, action: "refund.bulk_retried", targetType: "refund", targetId: "bulk", metadata: { ...result } });
    response.status(200).json(result);
  } catch (error) {
    if (!handleRefundError(response, error)) throw error;
  }
}

export async function exportRefundsCsvHandler(request: Request, response: Response): Promise<void> {
  try {
    const status = typeof request.query.status === "string" ? request.query.status as any : undefined;
    const csv = await exportRefundsCsv({ status });
    response.setHeader("Content-Type", "text/csv");
    response.setHeader("Content-Disposition", `attachment; filename="refunds-${Date.now()}.csv"`);
    response.status(200).send(csv);
  } catch (error) {
    if (!handleRefundError(response, error)) throw error;
  }
}
