import cron from "node-cron";
import { BookingStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";

let referralCreditingStarted = false;

export async function creditReferrals(): Promise<{ processed: number }> {
  const config = await prisma.platformConfig.findUnique({
    where: { key: "primary" },
    select: {
      referralRewardAmount: true,
      referralsEnabled: true,
      referralMaxSuccessfulPerReferrer: true
    }
  });
  const configuredReward = Number(config?.referralRewardAmount ?? 100);
  const referralsEnabled = config?.referralsEnabled ?? true;
  const referralLimit = config?.referralMaxSuccessfulPerReferrer ?? 0;
  if (!referralsEnabled || configuredReward <= 0) return { processed: 0 };

  const pendingReferrals = await prisma.referral.findMany({
    where: {
      status: "pending"
    }
  });

  let processed = 0;

  for (const referral of pendingReferrals) {
    try {
      const completedBooking = await prisma.booking.findFirst({
        where: {
          customerId: referral.referredUserId,
          status: BookingStatus.COMPLETED
        }
      });

      if (completedBooking) {
        const rewardAmount = Number(referral.rewardAmount) > 0
          ? Number(referral.rewardAmount)
          : configuredReward;
        const credited = await prisma.$transaction(async (tx) => {
          // Claim before touching the balance so concurrent scheduler runs can
          // never issue the same referral credit twice. Throwing below rolls
          // the claim back when the configured cap has been reached.
          const referralClaim = await tx.referral.updateMany({
            where: { id: referral.id, status: "pending" },
            data: { status: "completed", rewardAmount }
          });
          if (referralClaim.count !== 1) return false;

          const rewardSlot = await tx.user.updateMany({
            where: {
              id: referral.referrerId,
              ...(referralLimit > 0 ? { referralRewardsIssued: { lt: referralLimit } } : {})
            },
            data: { referralRewardsIssued: { increment: 1 } }
          });
          if (rewardSlot.count !== 1) {
            throw new Error("Referral reward limit reached");
          }

          const referrer = await tx.user.update({
            where: { id: referral.referrerId },
            data: {
              walletBalance: {
                increment: rewardAmount
              }
            }
          });

          await tx.walletTransaction.create({
            data: {
              userId: referral.referrerId,
              type: "CREDIT",
              amount: rewardAmount,
              referenceType: "REFERRAL_CREDIT",
              referenceId: referral.id,
              balanceAfter: referrer.walletBalance,
              metadata: { message: "Referral bonus", rewardAmount }
            }
          });
          return true;
        });

        if (credited) processed++;
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
