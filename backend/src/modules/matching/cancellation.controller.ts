import { Request, Response } from "express";
import {
  CancellationAccessError,
  CancellationConflictError,
  CancellationNotFoundError,
  cancellationService
} from "./cancellation.service.js";

type AuthenticatedRequest = Request & {
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
    sessionId: string;
  };
};

function handleCancellationError(response: Response, error: unknown): boolean {
  if (error instanceof CancellationNotFoundError) {
    response.status(404).json({ message: error.message });
    return true;
  }

  if (error instanceof CancellationAccessError) {
    response.status(403).json({ message: error.message });
    return true;
  }

  if (error instanceof CancellationConflictError) {
    response.status(409).json({ message: error.message });
    return true;
  }

  return false;
}

export async function cancelBookingHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;

  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  try {
    const requestedBy = authRequest.auth.role === "WORKER" ? "worker" : "customer";
    const result = await cancellationService.cancelBooking(
      String(request.params.bookingId),
      requestedBy,
      authRequest.auth.userId,
      request.body.reason
    );

    response.status(200).json(result);
  } catch (error) {
    if (!handleCancellationError(response, error)) {
      throw error;
    }
  }
}

