import { NextFunction, Request, Response } from "express";
import { verifyAccessToken } from "../lib/jwt.js";

export type AuthenticatedRequest = Request & {
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
    sessionId: string;
  };
};

export function requireAuth(request: AuthenticatedRequest, response: Response, next: NextFunction): void {
  const header = request.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    response.status(401).json({ message: "Missing bearer token" });
    return;
  }

  try {
    const token = header.slice(7);
    const payload = verifyAccessToken(token);
    request.auth = {
      userId: payload.sub,
      role: payload.role,
      sessionId: payload.sessionId
    };
    next();
  } catch {
    response.status(401).json({ message: "Invalid or expired token" });
  }
}

export function requireRole(...roles: Array<"CUSTOMER" | "WORKER" | "ADMIN">) {
  return (request: AuthenticatedRequest, response: Response, next: NextFunction): void => {
    if (!request.auth) {
      response.status(401).json({ message: "Authentication required" });
      return;
    }

    if (!roles.includes(request.auth.role)) {
      response.status(403).json({ message: "Insufficient permissions" });
      return;
    }

    next();
  };
}
