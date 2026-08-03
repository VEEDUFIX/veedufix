import { randomUUID } from "crypto";
import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { prisma } from "../../lib/prisma.js";
import { getTokensForUser } from "../device-token/device-token.service.js";
import { sendMulticastPush } from "../../lib/fcm.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import { logger } from "../../lib/logger.js";

export const adminNotificationsRouter = Router();
adminNotificationsRouter.use(requireAuth, requireRole("ADMIN"));

const broadcastSchema = z.object({
  body: z.object({
    title: z.string().min(1),
    body: z.string().min(1),
    targetRole: z.enum(["CUSTOMER", "WORKER", "ALL"]),
    route: z.string().optional()
  })
});

function getBroadcastData(data: unknown): { broadcastId: string | null; route: string | null; targetRole: string | null } {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    return { broadcastId: null, route: null, targetRole: null };
  }

  const payload = data as Record<string, unknown>;
  return {
    broadcastId: typeof payload.broadcastId === "string" ? payload.broadcastId : null,
    route: typeof payload.route === "string" ? payload.route : null,
    targetRole: typeof payload.targetRole === "string" ? payload.targetRole : null
  };
}

adminNotificationsRouter.get("/broadcasts", async (_req, res) => {
  const notifications = await prisma.notification.findMany({
    where: { type: "ADMIN_BROADCAST" },
    select: {
      title: true,
      body: true,
      data: true,
      createdAt: true
    },
    orderBy: { createdAt: "desc" },
    take: 1000
  });

  const groups = new Map<
    string,
    {
      broadcastId: string;
      title: string;
      body: string;
      route: string | null;
      targetRole: string | null;
      recipientCount: number;
      sentAt: string;
      _sentAtMs: number;
    }
  >();

  for (const notification of notifications) {
    const payload = getBroadcastData(notification.data);
    const sentAtMs = notification.createdAt.getTime();
    const key =
      payload.broadcastId ??
      `${notification.title}|${notification.body}|${payload.route ?? ""}|${payload.targetRole ?? ""}|${notification.createdAt
        .toISOString()
        .slice(0, 16)}`;

    const existing = groups.get(key);
    if (existing) {
      existing.recipientCount += 1;
      if (sentAtMs > existing._sentAtMs) {
        existing.sentAt = notification.createdAt.toISOString();
        existing._sentAtMs = sentAtMs;
      }
      continue;
    }

    groups.set(key, {
      broadcastId: payload.broadcastId ?? key,
      title: notification.title,
      body: notification.body,
      route: payload.route,
      targetRole: payload.targetRole,
      recipientCount: 1,
      sentAt: notification.createdAt.toISOString(),
      _sentAtMs: sentAtMs
    });
  }

  const broadcasts = Array.from(groups.values())
    .sort((a, b) => b._sentAtMs - a._sentAtMs)
    .slice(0, 20)
    .map(({ _sentAtMs, ...broadcast }) => broadcast);

  res.json({ broadcasts });
});

adminNotificationsRouter.post(
  "/broadcast",
  validate(broadcastSchema),
  async (req, res) => {
    try {
      const { title, body, targetRole, route } = req.body;
      const broadcastId = randomUUID();

      const userWhere = targetRole === "ALL" ? {} : { role: targetRole };

      // Find users matching the criteria
      const users = await prisma.user.findMany({
        where: userWhere,
        select: { id: true }
      });
      const userIds = users.map((user) => user.id);

      if (userIds.length === 0) {
        return res.json({
          success: true,
          totalCount: 0,
          successCount: 0,
          failureCount: 0,
          notificationCount: 0,
          message: "No matching users found"
        });
      }

      const data = {
        type: "ADMIN_BROADCAST",
        broadcastId,
        targetRole,
        ...(route ? { route } : {})
      };

      await prisma.notification.createMany({
        data: users.map((user) => ({
          userId: user.id,
          title,
          body,
          type: "ADMIN_BROADCAST",
          data
        }))
      });

      await Promise.all(
        users.map((user) =>
          publishNotificationEvent({
            userId: user.id,
            title,
            body,
            type: "ADMIN_BROADCAST",
            data
          })
        )
      );

      const tokens = [...new Set((await Promise.all(users.map((user) => getTokensForUser(user.id)))).flat())];
      let successCount = 0;
      let failureCount = 0;
      if (tokens.length > 0) {
        const pushResult = await sendMulticastPush({
          tokens,
          title,
          body,
          data
        });
        successCount = pushResult.successCount;
        failureCount = pushResult.failureCount;
      }

      logger.info(
        {
          targetRole,
          totalUsers: users.length
        },
        "Admin broadcast push notification sent"
      );

      return res.json({
        success: true,
        totalCount: users.length,
        successCount,
        failureCount,
        notificationCount: users.length
      });
    } catch (err) {
      logger.error({ err }, "Error sending admin broadcast");
      return res.status(500).json({ error: "Failed to broadcast notifications" });
    }
  }
);
