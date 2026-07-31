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

adminNotificationsRouter.post(
  "/broadcast",
  validate(broadcastSchema),
  async (req, res) => {
    try {
      const { title, body, targetRole, route } = req.body;

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
