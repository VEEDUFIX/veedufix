/**
 * Wallet Payout Processor
 *
 * Runs every hour at minute 30 and automatically processes PAYOUT_PENDING
 * transactions requested by workers from their Wallet screen.
 */
import cron from "node-cron";
import { logger } from "../../lib/logger.js";
import { processPendingWalletPayouts } from "../wallet/wallet.service.js";

export function startWalletPayoutProcessor(): void {
  // Run every hour at minute 30 to avoid colliding with payout-releaser
  cron.schedule("30 * * * *", async () => {
    logger.info("Wallet payout processor: starting scheduled run");
    try {
      await processPendingWalletPayouts();
    } catch (error) {
      logger.error({ error }, "Wallet payout processor: unhandled error in scheduled run");
    }
  });

  logger.info("Wallet payout processor: scheduled (every hour at :30)");
}
