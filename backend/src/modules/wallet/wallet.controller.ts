import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { applyReferralCode, generateReferralCode, getTransactions, getWalletBalance } from "./wallet.service.js";
import { logger } from "../../lib/logger.js";

export async function getWalletHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const userId = request.auth!.userId;
    let user = await getWalletBalance(userId);

    if (!user.referralCode) {
      const code = await generateReferralCode(userId);
      user.referralCode = code;
    }

    // Fetch customer transactions (no workerId needed for wallet view)
    const transactions = await getTransactions(userId);

    response.json({ balance: user.walletBalance, referralCode: user.referralCode, transactions });
  } catch (error) {
    logger.error({ error }, "Failed to get wallet");
    response.status(500).json({ message: "Internal server error" });
  }
}

export async function applyReferralHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const userId = request.auth!.userId;
    const { referralCode } = request.body;

    const result = await applyReferralCode(userId, referralCode);

    response.json(result);
  } catch (error) {
    logger.error({ error }, "Failed to apply referral code");
    if (error instanceof Error && (error.message.includes("Invalid") || error.message.includes("Cannot") || error.message.includes("already"))) {
      response.status(400).json({ message: "Unable to apply referral code" });
    } else {
      response.status(500).json({ message: "Internal server error" });
    }
  }
}

export async function requestPayoutHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const userId = request.auth!.userId;
    const role = request.auth!.role;
    const { amount } = request.body as { amount: number };

    if (role !== "WORKER") {
      return response.status(403).json({ message: "Only workers can request payouts" });
    }

    const workerProfile = await prisma.workerProfile.findUnique({
      where: { userId },
      select: { id: true, upiId: true }
    });

    if (!workerProfile) {
      return response.status(404).json({ message: "Worker profile not found" });
    }

    if (!workerProfile.upiId?.trim()) {
      return response.status(400).json({ message: "UPI ID is not configured for this worker" });
    }

    const lastTx = await prisma.walletTransaction.findFirst({
      where: { workerId: workerProfile.id },
      orderBy: { createdAt: "desc" },
      select: { balanceAfter: true }
    });

    const currentBalance = lastTx ? Number(lastTx.balanceAfter) : 0;
    if (amount > currentBalance) {
      return response.status(400).json({ message: "Insufficient wallet balance" });
    }

    const newBalance = currentBalance - amount;

    const tx = await prisma.walletTransaction.create({
      data: {
        userId,
        workerId: workerProfile.id,
        type: "PAYOUT_PENDING",
        amount: -amount,
        balanceAfter: newBalance,
        referenceType: "PAYOUT_REQUEST",
        metadata: {
          upiId: workerProfile.upiId.trim(),
          requestedAt: new Date().toISOString(),
          note: `UPI payout of ₹${amount} to ${workerProfile.upiId.trim()}`
        }
      }
    });

    logger.info({ userId, amount, transactionId: tx.id }, "Payout requested");
    response.status(201).json({
      success: true,
      transactionId: tx.id,
      amountRequested: amount,
      upiId: workerProfile.upiId.trim(),
      newBalance
    });
  } catch (error) {
    logger.error({ error }, "Failed to request payout");
    response.status(500).json({ message: "Internal server error" });
  }
}
