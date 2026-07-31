import { type Request, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  acceptJobOffer,
  assignJobWithFallback,
  DispatchConflictError,
  DispatchNotFoundError,
  findAvailableWorkers,
  OfferAuthorizationError,
  OfferExpiredError,
  rejectJobOffer
} from "./matching.service.js";

function handleMatchingError(response: Response, error: unknown): boolean {
  if (error instanceof DispatchNotFoundError) {
    response.status(404).json({ message: error.message });
    return true;
  }

  if (error instanceof DispatchConflictError) {
    response.status(409).json({ message: error.message });
    return true;
  }

  if (error instanceof OfferAuthorizationError) {
    response.status(403).json({ message: error.message });
    return true;
  }

  if (error instanceof OfferExpiredError) {
    response.status(410).json({ message: error.message });
    return true;
  }

  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
    return true;
  }

  return false;
}

export async function dispatchBookingHandler(request: Request, response: Response): Promise<void> {
  try {
    const result = await assignJobWithFallback(String(request.params.bookingId));

    // Payment verification and webhooks already trigger automatic dispatch.
    // This route remains as a manual/admin fallback for dispatch retries.
    response.status(result.status === "failed" ? 409 : 202).json(result);
  } catch (error) {
    if (!handleMatchingError(response, error)) {
      throw error;
    }
  }
}

export async function acceptJobHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await acceptJobOffer(String(request.params.bookingId), authRequest.auth!.userId);
    response.status(200).json(result);
  } catch (error) {
    if (!handleMatchingError(response, error)) {
      throw error;
    }
  }
}

export async function rejectJobHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await rejectJobOffer(String(request.params.bookingId), authRequest.auth!.userId);
    response.status(200).json(result);
  } catch (error) {
    if (!handleMatchingError(response, error)) {
      throw error;
    }
  }
}

export async function listAvailableWorkersHandler(request: Request, response: Response): Promise<void> {
  try {
    const workers = await findAvailableWorkers(String(request.params.bookingId));
    response.status(200).json({ workers });
  } catch (error) {
    if (!handleMatchingError(response, error)) {
      throw error;
    }
  }
}
