import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import {
  applyReferralCode,
  generateReferralCode,
  getTransactions,
  getWalletSummary,
  requestWorkerPayout
} from "./wallet.service.js";
import { logger } from "../../lib/logger.js";

export async function getWalletHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const userId = request.auth!.userId;
    let summary = await getWalletSummary(userId);

    if (!summary.referralCode) {
      const code = await generateReferralCode(userId);
      summary = { ...summary, referralCode: code };
    }

    const transactions = await getTransactions(userId);

    response.json({
      balance: summary.walletBalance,
      referralCode: summary.referralCode,
      totalReferrals: summary.totalReferrals,
      referralEarnings: summary.referralEarnings,
      transactions
    });
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
    const { amount, upiId } = request.body as { amount: number; upiId?: string };

    if (role !== "WORKER") {
      return response.status(403).json({ message: "Only workers can request payouts" });
    }

    const payout = await requestWorkerPayout({
      userId,
      amount,
      upiId
    });

    logger.info({ userId, amount, transactionId: payout.transaction.id }, "Payout requested");
    response.status(201).json({
      success: true,
      transactionId: payout.transaction.id,
      amountRequested: amount,
      upiId: payout.upiId,
      newBalance: payout.newBalance
    });
  } catch (error) {
    logger.error({ error }, "Failed to request payout");
    if (error instanceof Error) {
      if (error.message === "amount must be a positive number") {
        response.status(400).json({ message: error.message });
        return;
      }
      if (error.message === "Worker profile not found" || error.message === "UPI ID is not configured for this worker") {
        response.status(404).json({ message: error.message });
        return;
      }
      if (error.message === "Insufficient wallet balance" || error.message === "UPI ID does not match the worker profile") {
        response.status(400).json({ message: error.message });
        return;
      }
    }
    response.status(500).json({ message: "Internal server error" });
  }
}
