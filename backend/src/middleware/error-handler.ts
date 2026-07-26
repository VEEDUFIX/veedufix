import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { logger } from "../lib/logger.js";

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

  logger.error(error);
  response.status(500).json({
    message: "Internal server error"
  });
}
