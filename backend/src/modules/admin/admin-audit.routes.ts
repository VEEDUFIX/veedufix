import { Router } from "express";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";

export const adminAuditRouter = Router();

adminAuditRouter.use(requireAuth, requireRole("ADMIN"));

adminAuditRouter.get("/audit-logs", async (request: AuthenticatedRequest, response) => {
  try {
    const page = parseBoundedInteger(request.query.page, 1, 1, 1000);
    const limit = parseBoundedInteger(request.query.limit, 50, 1, 100);
    const skip = (page - 1) * limit;
    const q = typeof request.query.q === "string" ? request.query.q.trim() : "";
    const action = typeof request.query.action === "string" ? request.query.action.trim() : "";
    const targetType = typeof request.query.targetType === "string" ? request.query.targetType.trim() : "";

    const where = {
      ...(action ? { action: { contains: action, mode: "insensitive" as const } } : {}),
      ...(targetType ? { targetType: { contains: targetType, mode: "insensitive" as const } } : {}),
      ...(q
        ? {
            OR: [
              { action: { contains: q, mode: "insensitive" as const } },
              { targetType: { contains: q, mode: "insensitive" as const } },
              { targetId: { contains: q, mode: "insensitive" as const } },
              { note: { contains: q, mode: "insensitive" as const } },
              { adminId: { contains: q, mode: "insensitive" as const } }
            ]
          }
        : {})
    };

    const [total, logs] = await Promise.all([
      prisma.adminAuditLog.count({ where }),
      prisma.adminAuditLog.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip,
        take: limit,
        select: {
          id: true,
          adminId: true,
          action: true,
          targetType: true,
          targetId: true,
          note: true,
          metadata: true,
          createdAt: true
        }
      })
    ]);

    response.status(200).json({
      logs: logs.map((log) => ({
        id: log.id,
        adminId: log.adminId,
        action: log.action,
        targetType: log.targetType,
        targetId: log.targetId,
        note: log.note,
        metadata: log.metadata,
        createdAt: log.createdAt.toISOString()
      })),
      page,
      limit,
      total
    });
  } catch (error) {
    logger.error({ error }, "Failed to fetch audit logs");
    response.status(500).json({ message: "Internal server error" });
  }
});

adminAuditRouter.get("/audit-logs/:logId", async (request: AuthenticatedRequest, response) => {
  try {
    const logId = String(request.params.logId ?? "").trim();
    if (!logId) {
      response.status(400).json({ message: "logId is required" });
      return;
    }

    const log = await prisma.adminAuditLog.findUnique({
      where: { id: logId },
      select: {
        id: true,
        adminId: true,
        action: true,
        targetType: true,
        targetId: true,
        note: true,
        metadata: true,
        createdAt: true
      }
    });

    if (!log) {
      response.status(404).json({ message: "Audit log not found" });
      return;
    }

    response.status(200).json({
      log: {
        id: log.id,
        adminId: log.adminId,
        action: log.action,
        targetType: log.targetType,
        targetId: log.targetId,
        note: log.note,
        metadata: log.metadata,
        createdAt: log.createdAt.toISOString()
      }
    });
  } catch (error) {
    logger.error({ error }, "Failed to fetch audit log detail");
    response.status(500).json({ message: "Internal server error" });
  }
});

function parseBoundedInteger(
  value: unknown,
  fallback: number,
  min: number,
  max: number
): number {
  const parsed = typeof value === "string" || typeof value === "number" ? Number(value) : fallback;
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(Math.trunc(parsed), min), max);
}
