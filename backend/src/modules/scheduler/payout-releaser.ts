/**
 * Payout Releaser — 48-hour dispute grace period scheduler
 *
 * Runs every hour and automatically releases worker payouts for completed
 * bookings that are older than 48 hours AND have no open/under_review disputes.
 */
import cron from "node-cron";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { releaseWorkerPayout } from "../payout/payout.service.js";

const GRACE_PERIOD_MS = 48 * 60 * 60 * 1000; // 48 hours

async function releaseEligiblePayouts(): Promise<void> {
  const cutoff = new Date(Date.now() - GRACE_PERIOD_MS);

  // Find completed bookings older than 48h with no payout yet released
  // and no open or under_review dispute
  const eligibleBookings = await prisma.booking.findMany({
    where: {
      status: "COMPLETED",
      // scheduledAt is a proxy — completedAt lives on JobExecution
      // so we use jobExecution.completedAt via a join-style filter
      jobExecution: {
        status: "completed",
        completedAt: {
          lte: cutoff,
          not: null,
        },
      },
      // No open or in-review disputes
      disputes: {
        none: {
          status: {
            in: ["open", "under_review"],
          },
        },
      },
      // No existing successful payout
      payout: {
        is: null,
      },
    },
    select: {
      id: true,
      code: true,
      jobExecution: {
        select: {
          completedAt: true,
        },
      },
    },
    take: 100, // process in safe batches
  });

  if (eligibleBookings.length === 0) {
    logger.debug("Payout releaser: no eligible payouts to release");
    return;
  }

  logger.info(
    { count: eligibleBookings.length },
    "Payout releaser: releasing eligible worker payouts"
  );

  let released = 0;
  let failed = 0;

  for (const booking of eligibleBookings) {
    try {
      await releaseWorkerPayout(booking.id);
      released++;
      logger.info(
        { bookingId: booking.id, bookingCode: booking.code },
        "Payout releaser: payout released"
      );
    } catch (error) {
      failed++;
      logger.error(
        { error, bookingId: booking.id, bookingCode: booking.code },
        "Payout releaser: failed to release payout"
      );
    }
  }

  logger.info(
    { released, failed, total: eligibleBookings.length },
    "Payout releaser: batch complete"
  );
}

export function startPayoutReleaser(): void {
  // Run every hour at minute 15 to spread load away from top-of-hour spikes
  cron.schedule("15 * * * *", async () => {
    logger.info("Payout releaser: starting scheduled run");
    try {
      await releaseEligiblePayouts();
    } catch (error) {
      logger.error({ error }, "Payout releaser: unhandled error in scheduled run");
    }
  });

  logger.info("Payout releaser: scheduled (every hour at :15)");
}
