import { prisma as db } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";

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

export async function applyReferralCode(userId: string, referralCode: string) {
  const referrer = await db.user.findUnique({
    where: { referralCode }
  });

  if (!referrer) {
    throw new Error("Invalid referral code");
  }

  if (referrer.id === userId) {
    throw new Error("Cannot use your own referral code");
  }

  // Check if user already used a referral code
  const existing = await db.referral.findFirst({
    where: { referredUserId: userId }
  });

  if (existing) {
    throw new Error("Referral code already applied");
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
