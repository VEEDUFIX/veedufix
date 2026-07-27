import cron from "node-cron";
import { BookingStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import { assignJobWithFallback } from "../matching/matching.service.js";
import { suspendWorker } from "../worker-onboarding/worker-onboarding.service.js";

type NoShowBooking = {
  id: string;
  code: string;
  customerId: string;
  workerId: string | null;
  scheduledAt: Date;
  jobExecution: {
    status: string;
    arrivedAt: Date | null;
  } | null;
};

let noShowSchedulerStarted = false;

function getNoShowCutoff(): Date {
  return new Date(Date.now() - 20 * 60 * 1000);
}

async function notifyCustomerOfNoShow(booking: NoShowBooking): Promise<void> {
  await publishNotificationEvent({
    userId: booking.customerId,
    title: "Worker no-show",
    body: "Your assigned worker did not arrive. We are finding another worker.",
    type: "booking_cancelled_no_show",
    data: {
      bookingId: booking.id,
      bookingCode: booking.code,
      status: "cancelled_no_show"
    }
  });
}

async function processNoShowBooking(booking: NoShowBooking): Promise<void> {
  if (!booking.workerId || !booking.jobExecution) {
    return;
  }

  const updatedWorker = await prisma.$transaction(async (tx) => {
    await tx.booking.update({
      where: { id: booking.id },
      data: {
        status: BookingStatus.CANCELLED_NO_SHOW
      }
    });

    await tx.jobExecution.update({
      where: { bookingId: booking.id },
      data: {
        status: "cancelled"
      }
    });

    return tx.workerProfile.update({
      where: { id: booking.workerId! },
      data: {
        noShowCount: {
          increment: 1
        }
      },
      select: {
        id: true,
        noShowCount: true
      }
    });
  });

  await notifyCustomerOfNoShow(booking);

  if (updatedWorker.noShowCount >= 3) {
    await suspendWorker(updatedWorker.id, "system", "Auto-suspended: repeated no-shows");
  }

  try {
    await assignJobWithFallback(booking.id, [updatedWorker.id]);
  } catch (error) {
    logger.warn(
      {
        error,
        bookingId: booking.id,
        bookingCode: booking.code,
        workerProfileId: updatedWorker.id
      },
      "Automatic re-dispatch after no-show failed"
    );
  }
}

export async function checkForNoShows(): Promise<{ checked: number; processed: number }> {
  const cutoff = getNoShowCutoff();

  const bookings = await prisma.booking.findMany({
    where: {
      scheduledAt: {
        lte: cutoff
      },
      jobExecution: {
        is: {
          status: "assigned",
          arrivedAt: null
        }
      }
    },
    select: {
      id: true,
      code: true,
      customerId: true,
      workerId: true,
      scheduledAt: true,
      jobExecution: {
        select: {
          status: true,
          arrivedAt: true
        }
      }
    }
  });

  let processed = 0;

  for (const booking of bookings) {
    try {
      await processNoShowBooking(booking);
      processed += 1;
    } catch (error) {
      logger.warn(
        {
          error,
          bookingId: booking.id,
          bookingCode: booking.code
        },
        "No-show processing failed"
      );
    }
  }

  return {
    checked: bookings.length,
    processed
  };
}

export function startNoShowChecker(): void {
  if (noShowSchedulerStarted) {
    return;
  }

  noShowSchedulerStarted = true;

  cron.schedule("*/2 * * * *", () => {
    void checkForNoShows().catch((error) => {
      logger.error({ error }, "No-show checker run failed");
    });
  });

  void checkForNoShows().catch((error) => {
    logger.error({ error }, "Initial no-show checker run failed");
  });
}

