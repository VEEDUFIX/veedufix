import { prisma as db } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { env } from "../../config/env.js";
import { logger } from "../../lib/logger.js";

const REFERRAL_REWARD_AMOUNT = 100.0; // ₹100 for both referrer and referee

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
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { walletBalance: true, referralCode: true }
  });

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
    referralEarnings
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
  if (!Number.isFinite(input.amount) || input.amount <= 0) {
    throw AppError.badRequest("amount must be a positive number");
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
          upiId: storedUpiId,
          requestedAt: new Date().toISOString(),
          note: `UPI payout of INR ${input.amount} to ${storedUpiId}`
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
    // Create the referral record
    await tx.referral.create({
      data: {
        referrerId: referrer.id,
        referredUserId: userId,
        status: "completed",
        rewardAmount: REFERRAL_REWARD_AMOUNT
      }
    });

    // Update referrer balance
    const updatedReferrer = await tx.user.update({
      where: { id: referrer.id },
      data: {
        walletBalance: { increment: REFERRAL_REWARD_AMOUNT }
      }
    });

    // Create transaction for referrer
    await tx.walletTransaction.create({
      data: {
        userId: referrer.id,
        type: "REFERRAL_BONUS",
        amount: REFERRAL_REWARD_AMOUNT,
        referenceType: "REFERRAL_BONUS",
        balanceAfter: updatedReferrer.walletBalance
      }
    });

    // Update referred user balance
    const updatedReferred = await tx.user.update({
      where: { id: userId },
      data: {
        walletBalance: { increment: REFERRAL_REWARD_AMOUNT }
      }
    });

    // Create transaction for referred
    await tx.walletTransaction.create({
      data: {
        userId: userId,
        type: "REFERRAL_BONUS_RECEIVED",
        amount: REFERRAL_REWARD_AMOUNT,
        referenceType: "REFERRAL_BONUS_RECEIVED",
        balanceAfter: updatedReferred.walletBalance
      }
    });
  });

  return { success: true, rewardAmount: REFERRAL_REWARD_AMOUNT };
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
    try {
      // The amount is negative in DB, so we get the absolute value in paise
      const amountPaise = Math.round(Math.abs(Number(tx.amount)) * 100);
      
      const upiId = (tx.metadata as any)?.upiId;
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
          narration: `Wallet payout to ${upiId}`,
          fund_account: fundAccount,
          notes: {
            walletTransactionId: tx.id,
            workerId: tx.workerId ?? tx.userId
          }
        })
      });

      const payload = (await response.json().catch(() => null)) as any;

      if (!response.ok) {
        throw new Error(payload?.error?.description || payload?.error?.reason || `Razorpay payout request failed with status ${response.status}`);
      }

      const razorpayPayoutId = payload?.id;
      if (!razorpayPayoutId) {
        throw new Error("Razorpay payout response was malformed");
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
      const reason = error instanceof Error ? error.message : "Unknown error";
      logger.error({ error, txId: tx.id }, "Wallet payout processor: request failed");
      
      // Update transaction to failed and refund the wallet
      await db.$transaction(async (prismaTx) => {
        const failedTx = await prismaTx.walletTransaction.update({
          where: { id: tx.id },
          data: {
            type: "PAYOUT_FAILED",
            metadata: {
              ...(typeof tx.metadata === 'object' && tx.metadata !== null ? tx.metadata : {}),
              failureReason: reason,
              processedAt: new Date().toISOString(),
            }
          }
        });

        // Refund user wallet
        const refundAmount = Math.abs(Number(failedTx.amount));
        const updatedUser = await prismaTx.user.update({
          where: { id: failedTx.userId },
          data: {
            walletBalance: { increment: refundAmount }
          }
        });

        // Add refund transaction
        await prismaTx.walletTransaction.create({
          data: {
            userId: failedTx.userId,
            workerId: failedTx.workerId,
            type: "PAYOUT_REFUND",
            amount: refundAmount,
            referenceType: "PAYOUT_FAILED",
            referenceId: failedTx.id,
            balanceAfter: updatedUser.walletBalance,
            metadata: {
              note: `Refund for failed payout: ${reason}`
            }
          }
        });
      });
    }
  }
}
