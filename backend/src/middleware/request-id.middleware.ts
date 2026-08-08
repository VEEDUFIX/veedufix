import type { Request, Response, NextFunction } from "express";
import crypto from "crypto";

export function requestIdMiddleware(req: Request, res: Response, next: NextFunction) {
  const reqId = req.headers["x-request-id"] || crypto.randomUUID();
  req.id = reqId;
  res.setHeader("X-Request-ID", reqId);
  next();
}
