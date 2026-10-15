import cron from "node-cron";
import { logger } from "../../lib/logger.js";
import { processMaintenancePlanOccurrences } from "./maintenance.service.js";

let started = false;
let running = false;

async function runMaintenanceSweep(): Promise<void> {
  if (running) return;
  running = true;
  try {
    await processMaintenancePlanOccurrences();
  } catch (error) {
    logger.error({ error }, "Recurring maintenance scheduler sweep failed");
  } finally {
    running = false;
  }
}

export function startMaintenancePlanScheduler(): void {
  if (started) return;
  started = true;
  cron.schedule("*/15 * * * *", () => { void runMaintenanceSweep(); });
  void runMaintenanceSweep();
}
