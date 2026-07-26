import { NextFunction, Request, Response } from "express";
import { AnyZodObject } from "zod";

export function validate(schema: {
  body?: AnyZodObject;
  query?: AnyZodObject;
  params?: AnyZodObject;
}) {
  return (request: Request, response: Response, next: NextFunction): void => {
    try {
      if (schema.body) {
        request.body = schema.body.parse(request.body);
      }
      if (schema.query) {
        request.query = schema.query.parse(request.query) as typeof request.query;
      }
      if (schema.params) {
        request.params = schema.params.parse(request.params) as typeof request.params;
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
