import { NextFunction, Request, Response } from "express";
import { z } from "zod";

type ValidatedRequestShape = {
  body?: unknown;
  query?: unknown;
  params?: unknown;
};

export function validate(schema: z.ZodTypeAny) {
  return (request: Request, response: Response, next: NextFunction): void => {
    try {
      const parsed = schema.parse({
        body: request.body,
        query: request.query,
        params: request.params
      }) as ValidatedRequestShape;

      if (parsed.body !== undefined) {
        request.body = parsed.body;
      }
      if (parsed.query !== undefined) {
        request.query = parsed.query as typeof request.query;
      }
      if (parsed.params !== undefined) {
        request.params = parsed.params as typeof request.params;
      }
      next();
    } catch (error) {
      response.status(400).json({
        message: "Validation failed",
        issues: error instanceof Error ? error.message : "Unknown validation error"
      });
    }
  };
}
