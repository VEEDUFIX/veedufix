import { type NextFunction, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import { listEligibleWorkers } from "./worker-pool.service.js";

export async function listWorkerPoolHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const result = await listEligibleWorkers({
      page: request.query.page ? Number(request.query.page) : undefined,
      limit: request.query.limit ? Number(request.query.limit) : undefined,
      cityId: typeof request.query.cityId === "string" ? request.query.cityId : undefined,
      categoryId: typeof request.query.categoryId === "string" ? request.query.categoryId : undefined,
      onlyAvailable:
        typeof request.query.onlyAvailable === "string"
          ? request.query.onlyAvailable !== "false"
          : undefined
    });

    response.status(200).json(result);
  } catch (error) {
    if (error instanceof Error) {
      response.status(400).json({ message: error.message });
      return;
    }

    response.status(500).json({ message: "Unexpected error" });
  }
}

