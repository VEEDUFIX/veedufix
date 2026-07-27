import { logger } from "../../lib/logger.js";

export async function releaseWorkerPayout(bookingId: string): Promise<void> {
  logger.info({ bookingId }, "Worker payout release requested");
}
