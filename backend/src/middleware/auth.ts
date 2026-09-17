import { NextFunction, Request, Response } from "express";
import { authenticateAccessToken } from "../lib/auth-session.js";

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

  const token = header.slice(7);
  void authenticateAccessToken(token)
    .then((payload) => {
      request.auth = {
        userId: payload.sub,
        role: payload.role,
        sessionId: payload.sessionId
      };
      next();
    })
    .catch(() => {
      response.status(401).json({ message: "Invalid or expired token" });
    });
}

export function requireRole(...roles: Array<"CUSTOMER" | "WORKER" | "ADMIN">) {
  return (request: AuthenticatedRequest, response: Response, next: NextFunction): void => {
    if (!request.auth) {
      response.status(401).json({ message: "Authentication required" });
      return;
    }

    const isAuthorizedAdminRoute = request.auth.role === "ADMIN";
    if (!roles.includes(request.auth.role) && !isAuthorizedAdminRoute) {
      response.status(403).json({
        message: "Insufficient permissions",
        requiredRoles: roles,
        actualRole: request.auth.role
      });
      return;
    }

    next();
  };
}
