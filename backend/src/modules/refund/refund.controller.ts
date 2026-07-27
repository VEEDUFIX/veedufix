import { type Request, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  RefundConflictError,
  RefundNotFoundError,
  getAllRefunds,
  retryRefund
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
    response.status(200).json({ refund: result });
  } catch (error) {
    if (!handleRefundError(response, error)) {
      throw error;
    }
  }
}
