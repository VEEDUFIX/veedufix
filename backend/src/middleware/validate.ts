import { NextFunction, Request, Response } from "express";
import { z, ZodError } from "zod";

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
        Object.defineProperty(request, 'query', { value: parsed.query, writable: true });
      }
      if (parsed.params !== undefined) {
        Object.defineProperty(request, 'params', { value: parsed.params, writable: true });
      }
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        // Return structured, field-level issue objects so clients know exactly
        // which field failed and why (path + message), consistent with the
        // global error-handler's ZodError branch.
        response.status(400).json({
          message: "Validation failed",
          issues: error.issues.map((issue) => ({
            path: issue.path.join("."),
            message: issue.message
          }))
        });
        return;
      }

      response.status(400).json({
        message: "Validation failed",
        issues: [{ path: "", message: error instanceof Error ? error.message : "Unknown validation error" }]
      });
    }
  };
}
