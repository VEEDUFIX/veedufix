import { prisma as db } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { env } from "../../config/env.js";
import { logger } from "../../lib/logger.js";

const DEFAULT_REFERRAL_REWARD_AMOUNT = 100.0;
const DEFAULT_MINIMUM_WORKER_PAYOUT = 100.0;

async function getMoneyControls() {
  const config = await db.platformConfig.findUnique({
    where: { key: "primary" },
    select: {
      minimumWorkerPayout: true,
      referralRewardAmount: true,
      referralsEnabled: true,
      referralMaxSuccessfulPerReferrer: true,
      payoutsPaused: true,
      payoutPauseReason: true
    }
  });
  return {
    minimumWorkerPayout: Number(config?.minimumWorkerPayout ?? DEFAULT_MINIMUM_WORKER_PAYOUT),
    referralRewardAmount: Number(config?.referralRewardAmount ?? DEFAULT_REFERRAL_REWARD_AMOUNT),
    referralsEnabled: config?.referralsEnabled ?? true,
    referralMaxSuccessfulPerReferrer: config?.referralMaxSuccessfulPerReferrer ?? 0,
    payoutsPaused: config?.payoutsPaused ?? false,
    payoutPauseReason: config?.payoutPauseReason ?? null
  };
}

export async function getWalletBalance(userId: string) {
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { walletBalance: true, referralCode: true }
  });

  if (!user) {
    throw AppError.notFound("User not found");
  }

  return user;
}

export async function getWalletSummary(userId: string) {
  const [user, moneyControls] = await Promise.all([
    db.user.findUnique({
      where: { id: userId },
      select: { walletBalance: true, referralCode: true }
    }),
    getMoneyControls()
  ]);

  if (!user) {
    throw AppError.notFound("User not found");
  }

  // Count completed referrals made by this user
  const referrals = await db.referral.findMany({
    where: { referrerId: userId, status: "completed" },
    select: { rewardAmount: true }
  });

  const totalReferrals = referrals.length;
  const referralEarnings = referrals.reduce(
    (sum, r) => sum + Number(r.rewardAmount),
    0
  );

  return {
    walletBalance: user.walletBalance,
    referralCode: user.referralCode,
    totalReferrals,
    referralEarnings,
    referralRewardAmount: moneyControls.referralRewardAmount,
    referralsEnabled: moneyControls.referralsEnabled,
    referralMaxSuccessfulPerReferrer: moneyControls.referralMaxSuccessfulPerReferrer
  };
}

export async function generateReferralCode(userId: string) {
  const code = Math.random().toString(36).substring(2, 8).toUpperCase();
  await db.user.update({
    where: { id: userId },
    data: { referralCode: code }
  });
  return code;
}

export async function requestWorkerPayout(input: {
  userId: string;
  amount: number;
  upiId?: string;
}) {
  const moneyControls = await getMoneyControls();
  if (moneyControls.payoutsPaused) {
    throw AppError.badRequest(moneyControls.payoutPauseReason || "Partner payouts are temporarily paused by Veedufix");
  }
  const minimumWorkerPayout = moneyControls.minimumWorkerPayout;
  if (!Number.isFinite(input.amount) || input.amount < minimumWorkerPayout) {
    throw AppError.badRequest(`Minimum payout amount is ${minimumWorkerPayout}`);
  }
  if (Math.abs(input.amount * 100 - Math.round(input.amount * 100)) > 1e-8) {
    throw AppError.badRequest("Payout amount must have no more than two decimal places");
  }

  const result = await db.$transaction(async (tx) => {
    const workerProfile = await tx.workerProfile.findUnique({
      where: { userId: input.userId },
      select: {
        id: true,
        upiId: true
      }
    });

    if (!workerProfile) {
      throw AppError.notFound("Worker profile not found");
    }

    const storedUpiId = workerProfile.upiId?.trim();
    if (!storedUpiId) {
      throw AppError.badRequest("UPI ID is not configured for this worker");
    }

    if (input.upiId && input.upiId.trim() !== storedUpiId) {
      throw AppError.badRequest("UPI ID does not match the worker profile");
    }

    const updatedBalance = await tx.user.updateMany({
      where: {
        id: input.userId,
        walletBalance: { gte: input.amount }
      },
      data: {
        walletBalance: { decrement: input.amount }
      }
    });

    if (updatedBalance.count === 0) {
      throw AppError.badRequest("Insufficient wallet balance");
    }

    const user = await tx.user.findUnique({
      where: { id: input.userId },
      select: { walletBalance: true }
    });

    if (!user) {
      throw AppError.notFound("User not found");
    }

    const transaction = await tx.walletTransaction.create({
      data: {
        userId: input.userId,
        workerId: workerProfile.id,
        type: "PAYOUT_PENDING",
        amount: -input.amount,
        balanceAfter: user.walletBalance,
        referenceType: "PAYOUT_REQUEST",
        metadata: {
          requestedAt: new Date().toISOString(),
          payoutDestination: "verified_upi"
        }
      }
    });

    return {
      transaction,
      newBalance: Number(user.walletBalance),
      upiId: storedUpiId
    };
  });

  return result;
}

export async function applyReferralCode(userId: string, referralCode: string) {
  const { referralRewardAmount, referralsEnabled, referralMaxSuccessfulPerReferrer } = await getMoneyControls();
  if (!referralsEnabled || referralRewardAmount <= 0) {
    throw AppError.badRequest("Referral rewards are not currently available");
  }
  const referrer = await db.user.findUnique({
    where: { referralCode }
  });

  if (!referrer) {
    throw AppError.badRequest("Invalid referral code");
  }

  if (referrer.id === userId) {
    throw AppError.badRequest("Cannot use your own referral code");
  }

  // Check if user already used a referral code
  const existing = await db.referral.findFirst({
    where: { referredUserId: userId }
  });

  if (existing) {
    throw AppError.badRequest("Referral code already applied");
  }

  // Wrap in a transaction to prevent duplicate rewards under concurrent requests
  await db.$transaction(async (tx) => {
    const rewardSlot = await tx.user.updateMany({
      where: {
        id: referrer.id,
        ...(referralMaxSuccessfulPerReferrer > 0
          ? { referralRewardsIssued: { lt: referralMaxSuccessfulPerReferrer } }
          : {})
      },
      data: { referralRewardsIssued: { increment: 1 } }
    });
    if (rewardSlot.count === 0) {
      throw AppError.badRequest("Referral reward limit reached");
    }

    // Create the referral record
    await tx.referral.create({
      data: {
        referrerId: referrer.id,
        referredUserId: userId,
        status: "completed",
        rewardAmount: referralRewardAmount
      }
    });

    // Update referrer balance
    const updatedReferrer = await tx.user.update({
      where: { id: referrer.id },
      data: {
        walletBalance: { increment: referralRewardAmount }
      }
    });

    // Create transaction for referrer
    await tx.walletTransaction.create({
      data: {
        userId: referrer.id,
        type: "REFERRAL_BONUS",
        amount: referralRewardAmount,
        referenceType: "REFERRAL_BONUS",
        balanceAfter: updatedReferrer.walletBalance
      }
    });

    // Update referred user balance
    const updatedReferred = await tx.user.update({
      where: { id: userId },
      data: {
        walletBalance: { increment: referralRewardAmount }
      }
    });

    // Create transaction for referred
    await tx.walletTransaction.create({
      data: {
        userId: userId,
        type: "REFERRAL_BONUS_RECEIVED",
        amount: referralRewardAmount,
        referenceType: "REFERRAL_BONUS_RECEIVED",
        balanceAfter: updatedReferred.walletBalance
      }
    });
  });

  return { success: true, rewardAmount: referralRewardAmount };
}

export async function getTransactions(userId: string, workerId?: string) {
  if (workerId) {
    return await db.walletTransaction.findMany({
      where: { workerId },
      orderBy: { createdAt: "desc" }
    });
  } else {
    return await db.walletTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" }
    });
  }
}

function getRazorpayAuthHeader(): string {
  if (!env.RAZORPAY_KEY_ID || !env.RAZORPAY_KEY_SECRET) {
    throw new AppError(500, "Razorpay credentials are not configured");
  }
  return `Basic ${Buffer.from(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`).toString("base64")}`;
}

function getRazorpayAccountNumber(): string {
  if (!env.RAZORPAY_ACCOUNT_NUMBER || env.RAZORPAY_ACCOUNT_NUMBER.trim().length === 0) {
    throw new AppError(500, "RAZORPAY_ACCOUNT_NUMBER is not configured");
  }
  return env.RAZORPAY_ACCOUNT_NUMBER.trim();
}

export async function processPendingWalletPayouts(): Promise<void> {
  const pendingTransactions = await db.walletTransaction.findMany({
    where: {
      type: "PAYOUT_PENDING",
      referenceType: "PAYOUT_REQUEST",
    },
    include: {
      user: true,
      worker: true,
    },
    take: 50,
  });

  if (pendingTransactions.length === 0) {
    return;
  }

  logger.info({ count: pendingTransactions.length }, "Wallet payout processor: found pending requests");

  for (const tx of pendingTransactions) {
    if ((tx.metadata as { reconciliationRequired?: boolean } | null)?.reconciliationRequired) {
      continue;
    }

    try {
      // The amount is negative in DB, so we get the absolute value in paise
      const amountPaise = Math.round(Math.abs(Number(tx.amount)) * 100);
      
      const upiId = tx.worker?.upiId ?? (tx.metadata as any)?.upiId;
      if (!upiId) {
        throw new Error("Missing UPI ID in metadata");
      }
      
      const workerName = tx.worker?.fullName ?? tx.worker?.displayName ?? tx.user.name;
      const workerPhone = tx.user.phone?.replace(/\D/g, "") ?? "0000000000";

      const fundAccount = {
        account_type: "vpa",
        contact: {
          name: workerName,
          email: tx.user.email ?? undefined,
          contact: workerPhone,
          type: "employee",
          reference_id: `worker-${tx.workerId ?? tx.userId}`
        },
        vpa: {
          address: upiId
        }
      };

      const response = await fetch("https://api.razorpay.com/v1/payouts", {
        method: "POST",
        headers: {
          Authorization: getRazorpayAuthHeader(),
          "Content-Type": "application/json",
          "X-Payout-Idempotency": tx.id
        },
        body: JSON.stringify({
          account_number: getRazorpayAccountNumber(),
          amount: amountPaise,
          currency: "INR",
          mode: "UPI",
          purpose: "payout",
          queue_if_low_balance: false,
          reference_id: tx.id,
          narration: "Veedufix partner payout",
          fund_account: fundAccount,
          notes: {
            walletTransactionId: tx.id,
            workerId: tx.workerId ?? tx.userId
          }
        })
      });

      const payload = (await response.json().catch(() => null)) as any;

      if (!response.ok) {
        const isDefinitiveRejection =
          response.status >= 400 && response.status < 500 &&
          ![408, 409, 425, 429].includes(response.status);
        if (!isDefinitiveRejection) {
          await db.walletTransaction.updateMany({
            where: { id: tx.id, type: "PAYOUT_PENDING" },
            data: {
              metadata: {
                ...(typeof tx.metadata === 'object' && tx.metadata !== null ? tx.metadata : {}),
                reconciliationRequired: true,
                lastAttemptAt: new Date().toISOString()
              }
            }
          });
          logger.error({ txId: tx.id, status: response.status }, "Payout response requires reconciliation");
          continue;
        }
        throw new Error(`RazorpayRejected${response.status}`);
      }

      const razorpayPayoutId = payload?.id;
      if (!razorpayPayoutId) {
        await db.walletTransaction.updateMany({
          where: { id: tx.id, type: "PAYOUT_PENDING" },
          data: {
            metadata: {
              ...(typeof tx.metadata === 'object' && tx.metadata !== null ? tx.metadata : {}),
              reconciliationRequired: true,
              lastAttemptAt: new Date().toISOString()
            }
          }
        });
        logger.error({ txId: tx.id }, "Payout response requires reconciliation");
        continue;
      }

      // Success! Update transaction
      await db.walletTransaction.update({
        where: { id: tx.id },
        data: {
          type: "PAYOUT_SUCCESS",
          metadata: {
            ...(typeof tx.metadata === 'object' && tx.metadata !== null ? tx.metadata : {}),
            razorpayPayoutId,
            processedAt: new Date().toISOString(),
          }
        }
      });
      
      logger.info({ txId: tx.id, razorpayPayoutId }, "Wallet payout processor: request successful");

    } catch (error) {
      const reason = error instanceof Error ? error.name : "UnknownError";
      logger.error({ errorName: reason, txId: tx.id }, "Wallet payout processor: request outcome is uncertain");
      const currentMetadata = typeof tx.metadata === 'object' && tx.metadata !== null ? tx.metadata : {};
      if ((currentMetadata as { reconciliationRequired?: boolean }).reconciliationRequired) continue;

      // Network failures may happen after the payout provider accepted the
      // request. Keep the debit pending for reconciliation rather than risk
      // refunding a payout that may already have been sent.
      if (!(error instanceof Error && error.message.startsWith("RazorpayRejected"))) {
        await db.walletTransaction.updateMany({
          where: { id: tx.id, type: "PAYOUT_PENDING" },
          data: {
            metadata: {
              ...currentMetadata,
              reconciliationRequired: true,
              lastAttemptAt: new Date().toISOString()
            }
          }
        });
        continue;
      }
      
      // Update transaction to failed and refund the wallet
      await db.$transaction(async (prismaTx) => {
        const claimed = await prismaTx.walletTransaction.updateMany({
          where: { id: tx.id, type: "PAYOUT_PENDING" },
          data: {
            type: "PAYOUT_FAILED",
            metadata: {
              ...(typeof tx.metadata === 'object' && tx.metadata !== null ? tx.metadata : {}),
              failureCode: reason,
              processedAt: new Date().toISOString(),
            }
          }
        });

        if (claimed.count === 0) return;

        // Refund user wallet
        const refundAmount = Math.abs(Number(tx.amount));
        const updatedUser = await prismaTx.user.update({
          where: { id: tx.userId },
          data: {
            walletBalance: { increment: refundAmount }
          }
        });

        // Add refund transaction
        await prismaTx.walletTransaction.create({
          data: {
            userId: tx.userId,
            workerId: tx.workerId,
            type: "PAYOUT_REFUND",
            amount: refundAmount,
            referenceType: "PAYOUT_FAILED",
            referenceId: tx.id,
            balanceAfter: updatedUser.walletBalance,
            metadata: {
              note: "Refund for failed payout"
            }
          }
        });
      });
    }
  }
}
