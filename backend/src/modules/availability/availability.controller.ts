import { type NextFunction, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  WorkerAvailabilityNotFoundError,
  getWorkerProfileIdByUserId,
  getWorkerAvailability,
  setWeeklyAvailability
} from "./availability.service.js";

function sendError(response: Response, error: unknown): void {
  if (error instanceof WorkerAvailabilityNotFoundError) {
    response.status(404).json({ message: error.message });
    return;
  }

  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
    return;
  }

  response.status(500).json({ message: "Unexpected error" });
}

function requireWorker(request: AuthenticatedRequest, response: Response): boolean {
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

export async function setWeeklyAvailabilityHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!requireWorker(request, response)) {
    return;
  }

  try {
    const workerId = await getWorkerProfileIdByUserId(request.auth!.userId);
    const slots = await setWeeklyAvailability(workerId, request.body.slots);
    response.status(200).json({ slots });
  } catch (error) {
    sendError(response, error);
  }
}

export async function getMyAvailabilityHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!requireWorker(request, response)) {
    return;
  }

  try {
    const workerId = await getWorkerProfileIdByUserId(request.auth!.userId);
    const slots = await getWorkerAvailability(workerId);
    response.status(200).json({ slots });
  } catch (error) {
    sendError(response, error);
  }
}

export async function getPublicAvailabilityHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  try {
    const slots = await getWorkerAvailability(String(request.params.workerId));
    response.status(200).json({ slots });
  } catch (error) {
    sendError(response, error);
  }
}

export async function toggleAvailabilityHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!requireWorker(request, response)) {
    return;
  }

  try {
    const { isAvailable } = request.body as { isAvailable: boolean };
    if (typeof isAvailable !== "boolean") {
      response.status(400).json({ message: "isAvailable must be a boolean" });
      return;
    }
    const workerId = await getWorkerProfileIdByUserId(request.auth!.userId);
    await import("../../lib/prisma.js").then(({ prisma }) =>
      prisma.workerProfile.update({
        where: { id: workerId },
        data: { isAvailable },
      })
    );
    response.status(200).json({ isAvailable });
  } catch (error) {
    sendError(response, error);
  }
}
