import { Request, Response } from "express";
import {
  BookingNotFoundError,
  DisputeAccessError,
  DisputeConflictError,
  DisputeNotFoundError,
  DisputeWindowExpiredError,
  disputeService
} from "./dispute.service.js";

type AuthenticatedRequest = Request & {
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
    sessionId: string;
  };
};

function handleDisputeError(response: Response, error: unknown): boolean {
  if (error instanceof BookingNotFoundError) {
    response.status(404).json({ message: error.message });
    return true;
  }

  if (error instanceof DisputeNotFoundError) {
    response.status(404).json({ message: error.message });
    return true;
  }

  if (error instanceof DisputeAccessError) {
    response.status(403).json({ message: error.message });
    return true;
  }

  if (error instanceof DisputeWindowExpiredError) {
    response.status(410).json({ message: error.message });
    return true;
  }

  if (error instanceof DisputeConflictError) {
    response.status(409).json({ message: error.message });
    return true;
  }

  return false;
}

export async function raiseDisputeHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;

  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  try {
    const dispute = await disputeService.raiseDispute(
      String(request.params.bookingId),
      authRequest.auth.userId,
      request.body.reason
    );

    response.status(201).json(dispute);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}

export async function listDisputesHandler(request: Request, response: Response): Promise<void> {
  try {
    const result = await disputeService.listOpenDisputes({
      city: typeof request.query.city === "string" ? request.query.city : undefined,
      page:
        typeof request.query.page === "number" ? request.query.page : Number(request.query.page ?? 1),
      pageSize:
        typeof request.query.pageSize === "number" ? request.query.pageSize : Number(request.query.pageSize ?? 20)
    });

    response.status(200).json(result);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}

export async function getDisputeEvidenceHandler(request: Request, response: Response): Promise<void> {
  try {
    const result = await disputeService.getDisputeEvidence(String(request.params.disputeId));
    response.status(200).json(result);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}

export async function resolveDisputeHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;

  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  try {
    const result = await disputeService.resolveDispute(
      String(request.params.disputeId),
      authRequest.auth.userId,
      request.body.resolution,
      request.body.note
    );

    response.status(200).json(result);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}
