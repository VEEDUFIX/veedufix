import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { logger } from "../lib/logger.js";
import { AppError } from "../lib/app-error.js";

export function notFoundHandler(request: Request, response: Response): void {
  response.status(404).json({
    message: `Route not found: ${request.method} ${request.path}`
  });
}

export function errorHandler(
  error: Error,
  _request: Request,
  response: Response,
  _next: NextFunction
): void {
  if (error instanceof ZodError) {
    response.status(400).json({
      message: "Validation failed",
      issues: error.issues
    });
    return;
  }

  // Domain errors carry their own status code — return them directly without
  // logging as server errors, since these are expected user-facing failures.
  if (error instanceof AppError) {
    response.status(error.statusCode).json({ message: error.message });
    return;
  }

  logger.error(error);
  response.status(500).json({
    message: "Internal server error"
  });
}
