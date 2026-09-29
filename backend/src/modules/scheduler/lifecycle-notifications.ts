import cron from "node-cron";
import { createHash, randomUUID } from "node:crypto";
import { BookingStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { sendPushNotification } from "../../lib/fcm.js";
import { redis } from "../../lib/redis.js";

const DEDUPE_TTL_SECONDS = 60 * 60 * 24 * 30;
const CLAIM_TTL_SECONDS = 60 * 5;
let lifecycleNotificationsStarted = false;

async function claimNotification(key: string): Promise<string | null> {
  const claimId = randomUUID();
  const claimKey = `${key}:claim`;
  if ((await redis.set(claimKey, claimId, "EX", CLAIM_TTL_SECONDS, "NX")) !== "OK") return null;
  if (await redis.exists(`${key}:sent`) || await redis.exists(key)) {
    await releaseNotification(key, claimId);
    return null;
  }
  return claimId;
}

async function releaseNotification(key: string, claimId: string): Promise<void> {
  await redis.eval(
    "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
    1,
    `${key}:claim`,
    claimId
  );
}

async function completeNotification(key: string, claimId: string): Promise<void> {
  const completed = await redis.eval(
    "if redis.call('get', KEYS[1]) == ARGV[1] then redis.call('set', KEYS[2], '1', 'EX', ARGV[2]); return redis.call('del', KEYS[1]) else return 0 end",
    2,
    `${key}:claim`,
    `${key}:sent`,
    claimId,
    DEDUPE_TTL_SECONDS
  );
  if (completed !== 1) throw new Error("Lifecycle notification claim expired before completion");
}

async function sendToRecipient(input: {
  key: string;
  userId: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<void> {
  const devices = await prisma.deviceToken.findMany({
    where: { userId: input.userId },
    select: { token: true }
  });
  const tokens = [...new Set(devices.map((device) => device.token).filter(Boolean))];
  for (const token of tokens) {
    const tokenHash = createHash("sha256").update(token).digest("hex");
    const dedupeKey = `${input.key}:device:${tokenHash}`;
    const claimId = await claimNotification(dedupeKey);
    if (!claimId) continue;

    try {
      const result = await sendPushNotification({
        token,
        title: input.title,
        body: input.body,
        data: input.data
      });
      if (!result.success) throw new Error(result.error || "Push delivery failed");
      await completeNotification(dedupeKey, claimId);
    } catch (error) {
      await releaseNotification(dedupeKey, claimId).catch(() => undefined);
      throw error;
    }
  }
}

async function sendBookingReminders() {
  const now = new Date();
  const minTime = new Date(now.getTime() + 55 * 60 * 1000);
  const maxTime = new Date(now.getTime() + 65 * 60 * 1000);

  const bookings = await prisma.booking.findMany({
    where: {
      status: { in: [BookingStatus.ACCEPTED, BookingStatus.WORKER_ASSIGNED] },
      scheduledAt: {
        gte: minTime,
        lte: maxTime,
      }
    },
    include: {
      services: {
        include: {
          serviceSubcategory: true
        }
      },
      address: true,
    }
  });

  for (const booking of bookings) {
    const dedupeKey = `lifecycle:booking-reminder:${booking.id}:${booking.scheduledAt.getTime()}`;
    try {
      const serviceName = booking.services[0]?.serviceSubcategory?.name || "Service";
      const timeStr = booking.scheduledAt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

      // Notify customer
      await sendToRecipient({
        key: dedupeKey,
        userId: booking.customerId,
        title: "Your booking is in 1 hour! ⏰",
        body: `${serviceName} is scheduled for ${timeStr}. Your worker is on the way.`,
        data: { type: "BOOKING_DETAIL", bookingId: booking.id }
      });

      // Notify worker
      if (booking.workerId) {
        const workerProfile = await prisma.workerProfile.findUnique({
          where: { id: booking.workerId },
          select: { userId: true }
        });

        if (workerProfile?.userId) {
          const customerAddress = booking.address?.line1 || "Customer location";
          await sendToRecipient({
            key: dedupeKey,
            userId: workerProfile.userId,
            title: "Job in 1 hour 🔧",
            body: `Reminder: ${serviceName} at ${customerAddress} starts at ${timeStr}.`,
            data: { type: "JOB_ASSIGNED", bookingId: booking.id }
          });
        }
      }

    } catch (err) {
      logger.error({ error: err, bookingId: booking.id }, "Failed to send booking reminder");
    }
  }
}

async function sendReviewRequests() {
  const now = new Date();
  const maxTime = new Date(now.getTime() - 25 * 60 * 1000);
  const minTime = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const bookings = await prisma.booking.findMany({
    where: {
      status: BookingStatus.COMPLETED,
      jobExecution: {
        completedAt: {
          gte: minTime,
          lte: maxTime,
        }
      },
      reviews: {
        none: {}
      }
    },
    include: {
      services: {
        include: {
          serviceSubcategory: true
        }
      }
    }
  });

  for (const booking of bookings) {
    const dedupeKey = `lifecycle:review-request:${booking.id}`;
    try {
      const serviceName = booking.services[0]?.serviceSubcategory?.name || "Service";

      await sendToRecipient({
        key: dedupeKey,
        userId: booking.customerId,
        title: "How was your experience? ⭐",
        body: `Rate your ${serviceName} session and help us improve.`,
        data: { type: "REVIEW_REQUEST", bookingId: booking.id }
      });
    } catch (err) {
      logger.error({ error: err, bookingId: booking.id }, "Failed to send review request");
    }
  }
}

async function sendCustomQuoteReady() {
  const now = new Date();
  const maxAge = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const readyBefore = new Date(now.getTime() - 2 * 60 * 1000);

  const bookings = await prisma.booking.findMany({
    where: {
      customQuoteStatus: 'SUBMITTED',
      updatedAt: {
        gte: maxAge,
        lte: readyBefore
      }
    },
    include: {
      services: {
        include: {
          serviceSubcategory: true
        }
      }
    }
  });

  for (const booking of bookings) {
    const dedupeKey = `lifecycle:quote-ready:${booking.id}:${booking.updatedAt.getTime()}`;
    try {
      const serviceName = booking.services[0]?.serviceSubcategory?.name || "Service";

      await sendToRecipient({
        key: dedupeKey,
        userId: booking.customerId,
        title: "Your custom quote is ready! 💰",
        body: `Review and accept your quote for ${serviceName}.`,
        data: { type: "CUSTOM_QUOTE_READY", bookingId: booking.id }
      });
    } catch (err) {
      logger.error({ error: err, bookingId: booking.id }, "Failed to send quote ready notification");
    }
  }
}

export async function processLifecycleNotifications(): Promise<void> {
  await Promise.all([
    sendBookingReminders().catch(err => logger.error({ error: err }, "Error in sendBookingReminders")),
    sendReviewRequests().catch(err => logger.error({ error: err }, "Error in sendReviewRequests")),
    sendCustomQuoteReady().catch(err => logger.error({ error: err }, "Error in sendCustomQuoteReady")),
  ]);
}

export function startLifecycleNotifications(): void {
  if (lifecycleNotificationsStarted) return;
  lifecycleNotificationsStarted = true;

  cron.schedule("*/5 * * * *", () => {
    void processLifecycleNotifications().catch((error) => {
      logger.error({ error }, "Lifecycle notifications run failed");
    });
  });

  void processLifecycleNotifications().catch((error) => {
    logger.error({ error }, "Initial lifecycle notifications run failed");
  });
}
