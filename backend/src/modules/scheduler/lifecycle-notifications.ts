import cron from "node-cron";
import { BookingStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { sendMulticastPush } from "../../lib/fcm.js";

const sentReminders = new Set<string>();
const sentReviewRequests = new Set<string>();
const sentQuoteReady = new Set<string>();
let lifecycleNotificationsStarted = false;

async function sendBookingReminders() {
  const now = new Date();
  const minTime = new Date(now.getTime() + 55 * 60 * 1000);
  const maxTime = new Date(now.getTime() + 65 * 60 * 1000);

  const bookings = await prisma.booking.findMany({
    where: {
      status: BookingStatus.ACCEPTED,
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
    if (sentReminders.has(booking.id)) continue;
    
    try {
      const serviceName = booking.services[0]?.serviceSubcategory?.name || "Service";
      const timeStr = booking.scheduledAt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

      // Notify customer
      const customerTokens = await prisma.deviceToken.findMany({
        where: { userId: booking.customerId },
        select: { token: true }
      });
      const cTokenStrings = customerTokens.map(t => t.token).filter(Boolean);
      if (cTokenStrings.length > 0) {
        await sendMulticastPush({
          tokens: cTokenStrings,
          title: "Your booking is in 1 hour! ⏰",
          body: `${serviceName} is scheduled for ${timeStr}. Your worker is on the way.`,
        });
      }

      // Notify worker
      if (booking.workerId) {
        const workerProfile = await prisma.workerProfile.findUnique({
          where: { id: booking.workerId },
          select: { userId: true }
        });

        if (workerProfile?.userId) {
          const workerTokens = await prisma.deviceToken.findMany({
            where: { userId: workerProfile.userId },
            select: { token: true }
          });
          const wTokenStrings = workerTokens.map(t => t.token).filter(Boolean);
          if (wTokenStrings.length > 0) {
            const customerAddress = booking.address?.line1 || "Customer location";
            await sendMulticastPush({
              tokens: wTokenStrings,
              title: "Job in 1 hour 🔧",
              body: `Reminder: ${serviceName} at ${customerAddress} starts at ${timeStr}.`,
            });
          }
        }
      }

      sentReminders.add(booking.id);
    } catch (err) {
      logger.error({ error: err, bookingId: booking.id }, "Failed to send booking reminder");
    }
  }
}

async function sendReviewRequests() {
  const now = new Date();
  const minTime = new Date(now.getTime() - 35 * 60 * 1000);
  const maxTime = new Date(now.getTime() - 25 * 60 * 1000);

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
    if (sentReviewRequests.has(booking.id)) continue;
    try {
      const serviceName = booking.services[0]?.serviceSubcategory?.name || "Service";
      
      const tokens = await prisma.deviceToken.findMany({
        where: { userId: booking.customerId },
        select: { token: true }
      });
      const tokenStrings = tokens.map(t => t.token).filter(Boolean);
      if (tokenStrings.length > 0) {
        await sendMulticastPush({
          tokens: tokenStrings,
          title: "How was your experience? ⭐",
          body: `Rate your ${serviceName} session and help us improve.`,
          data: { type: 'REVIEW_REQUEST', bookingId: booking.id }
        });
      }
      
      sentReviewRequests.add(booking.id);
    } catch (err) {
      logger.error({ error: err, bookingId: booking.id }, "Failed to send review request");
    }
  }
}

async function sendCustomQuoteReady() {
  const now = new Date();
  const minTime = new Date(now.getTime() - 2 * 60 * 1000);

  const bookings = await prisma.booking.findMany({
    where: {
      customQuoteStatus: 'SUBMITTED',
      updatedAt: {
        gte: minTime
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
    if (sentQuoteReady.has(booking.id)) continue;
    try {
      const serviceName = booking.services[0]?.serviceSubcategory?.name || "Service";
      
      const tokens = await prisma.deviceToken.findMany({
        where: { userId: booking.customerId },
        select: { token: true }
      });
      const tokenStrings = tokens.map(t => t.token).filter(Boolean);
      if (tokenStrings.length > 0) {
        await sendMulticastPush({
          tokens: tokenStrings,
          title: "Your custom quote is ready! 💰",
          body: `Review and accept your quote for ${serviceName}.`,
          data: { type: 'CUSTOM_QUOTE_READY', bookingId: booking.id }
        });
      }
      
      sentQuoteReady.add(booking.id);
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
