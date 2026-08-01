import { Router } from "express";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";

export const adminAuditRouter = Router();

adminAuditRouter.use(requireAuth, requireRole("ADMIN"));

adminAuditRouter.get("/audit-logs", async (request: AuthenticatedRequest, response) => {
  const page = Math.max(Number(request.query.page ?? 1), 1);
  const limit = Math.min(Math.max(Number(request.query.limit ?? 50), 1), 100);
  const skip = (page - 1) * limit;
  const q = typeof request.query.q === "string" ? request.query.q.trim() : "";
  const action = typeof request.query.action === "string" ? request.query.action.trim() : "";
  const targetType = typeof request.query.targetType === "string" ? request.query.targetType.trim() : "";

  const where = {
    ...(action ? { action } : {}),
    ...(targetType ? { targetType } : {}),
    ...(q
      ? {
          OR: [
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
});
