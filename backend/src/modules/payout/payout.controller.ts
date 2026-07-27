import { type NextFunction, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import { getAllPayouts, retryPayout } from "./payout.service.js";

function sendError(response: Response, error: unknown): void {
  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
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
    const result = await retryPayout(String(request.params.payoutId));
    response.status(200).json({ payout: result });
  } catch (error) {
    sendError(response, error);
  }
}
