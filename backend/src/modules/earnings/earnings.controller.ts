import { type NextFunction, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  WorkerProfileNotFoundError,
  getWorkerEarningsSummary,
  getWorkerTransactionHistory
} from "./earnings.service.js";

function sendError(response: Response, error: unknown): void {
  if (error instanceof WorkerProfileNotFoundError) {
    response.status(404).json({ message: error.message });
    return;
  }

  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
    return;
  }

  response.status(500).json({ message: "Unexpected error" });
}

function assertWorkerAccess(request: AuthenticatedRequest, response: Response): boolean {
  if (!request.auth) {
    response.status(401).json({ message: "Authentication required" });
    return false;
  }

  if (request.auth.role !== "WORKER") {
    response.status(403).json({ message: "Insufficient permissions" });
    return false;
  }

  return true;
}

export async function getWorkerEarningsSummaryHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!assertWorkerAccess(request, response)) {
    return;
  }

  try {
    const result = await getWorkerEarningsSummary(request.auth!.userId);
    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function getWorkerTransactionHistoryHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!assertWorkerAccess(request, response)) {
    return;
  }

  try {
    const result = await getWorkerTransactionHistory(
      request.auth!.userId,
      {
        fromDate: request.query.fromDate as Date | undefined,
        toDate: request.query.toDate as Date | undefined,
        status: request.query.status as "pending" | "processing" | "success" | "failed" | undefined
      },
      {
        page: Number(request.query.page),
        limit: Number(request.query.limit)
      }
    );

    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}
