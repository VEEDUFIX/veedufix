import cron from "node-cron";
import { BookingStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";

let referralCreditingStarted = false;

export async function creditReferrals(): Promise<{ processed: number }> {
  // We use a workaround because Referral model is missing creditedAt DateTime? field.
  // Check if WalletTransaction with referenceType 'REFERRAL_CREDIT' and referral.id exists.
  const pendingReferrals = await prisma.referral.findMany({
    where: {
      status: "pending"
    }
  });

  let processed = 0;

  for (const referral of pendingReferrals) {
    try {
      const existingTx = await prisma.walletTransaction.findFirst({
        where: {
          referenceType: "REFERRAL_CREDIT",
          referenceId: referral.id
        }
      });

      if (existingTx) {
        continue;
      }

      const completedBooking = await prisma.booking.findFirst({
        where: {
          customerId: referral.referredUserId,
          status: BookingStatus.COMPLETED
        }
      });

      if (completedBooking) {
        await prisma.$transaction(async (tx) => {
          const referrer = await tx.user.update({
            where: { id: referral.referrerId },
            data: {
              walletBalance: {
                increment: 100
              }
            }
          });

          await tx.walletTransaction.create({
            data: {
              userId: referral.referrerId,
              type: "CREDIT",
              amount: 100,
              referenceType: "REFERRAL_CREDIT",
              referenceId: referral.id,
              balanceAfter: referrer.walletBalance,
              metadata: { message: "Referral bonus" }
            }
          });

          await tx.referral.update({
            where: { id: referral.id },
            data: {
              status: "completed",
              rewardAmount: 100
            }
          });
        });

        processed++;
      }
    } catch (error) {
      logger.error({ error, referralId: referral.id }, "Failed to process referral crediting");
    }
  }

  return { processed };
}

export function startReferralCrediting(): void {
  if (referralCreditingStarted) return;
  referralCreditingStarted = true;

  cron.schedule("0 * * * *", () => {
    void creditReferrals().catch((error) => {
      logger.error({ error }, "Referral crediting run failed");
    });
  });

  void creditReferrals().catch((error) => {
    logger.error({ error }, "Initial referral crediting run failed");
  });
}
