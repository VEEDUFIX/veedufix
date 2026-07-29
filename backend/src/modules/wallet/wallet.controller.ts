import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
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
      response.status(400).json({ message: error.message });
    } else {
      response.status(500).json({ message: "Internal server error" });
    }
  }
}

export async function requestPayoutHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const userId = request.auth!.userId;
    const role = request.auth!.role;

    if (role !== "WORKER") {
      return response.status(403).json({ message: "Only workers can request payouts" });
    }

    // In a real app, this would deduct the balance and create a Payout request record
    // For now, just simulate success
    logger.info({ userId }, "Payout requested");
    response.json({ success: true, message: "Payout requested successfully" });
  } catch (error) {
    logger.error({ error }, "Failed to request payout");
    response.status(500).json({ message: "Internal server error" });
  }
}
