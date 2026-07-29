/**
 * Dispute Auto-Escalation
 *
 * Runs every hour and promotes open disputes that have been sitting for more
 * than 48 hours to "under_review" status, and flags them as high-severity
 * OpsAlerts so they surface prominently in the admin panel.
 */

import cron from "node-cron";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";

const ESCALATION_THRESHOLD_MS = 48 * 60 * 60 * 1000; // 48 hours

let disputeEscalationStarted = false;

export async function escalateStaleDisputes(): Promise<{ checked: number; escalated: number }> {
  const cutoff = new Date(Date.now() - ESCALATION_THRESHOLD_MS);

  const staleDisputes = await prisma.dispute.findMany({
    where: {
      status: "open",
      createdAt: { lte: cutoff }
    },
    select: {
      id: true,
      bookingId: true,
      reason: true,
      booking: {
        select: {
          code: true
        }
      }
    },
    take: 100
  });

  let escalated = 0;

  for (const dispute of staleDisputes) {
    try {
      await prisma.$transaction(async (tx) => {
        // Promote to under_review so it appears in the review queue
        await tx.dispute.update({
          where: { id: dispute.id },
          data: { status: "under_review" }
        });

        // Create or update an OpsAlert so it surfaces in the admin Alerts feed
        const sourceId = `dispute-escalation-${dispute.id}`;
        const existingAlert = await tx.opsAlert.findUnique({ where: { sourceId } });

        if (!existingAlert) {
          await tx.opsAlert.create({
            data: {
              sourceId,
              type: "payment_mismatch", // closest generic type available
              bookingId: dispute.bookingId,
              message: `Dispute on booking ${dispute.booking?.code ?? dispute.bookingId} has been open for over 48 hours and requires urgent review.`,
              severity: "critical",
              status: "open",
              metadata: {
                disputeId: dispute.id,
                bookingCode: dispute.booking?.code,
                reason: dispute.reason,
                title: "Stale dispute requires urgent review",
                retryAvailable: false
              }
            }
          });
        }
      });

      escalated++;

      logger.info(
        { disputeId: dispute.id, bookingCode: dispute.booking?.code },
        "Dispute auto-escalated to under_review after 48h"
      );
    } catch (error) {
      logger.warn({ error, disputeId: dispute.id }, "Failed to escalate stale dispute");
    }
  }

  return { checked: staleDisputes.length, escalated };
}

export function startDisputeEscalation(): void {
  if (disputeEscalationStarted) return;
  disputeEscalationStarted = true;

  // Run once at startup to catch any backlog
  void escalateStaleDisputes().catch((error) => {
    logger.error({ error }, "Initial dispute escalation run failed");
  });

  // Then run every hour
  cron.schedule("0 * * * *", () => {
    void escalateStaleDisputes().catch((error) => {
      logger.error({ error }, "Dispute escalation cron run failed");
    });
  });

  logger.info("Dispute auto-escalation cron started");
}
