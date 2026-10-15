import cron from "node-cron";
import { logger } from "../../lib/logger.js";
import { cleanupExpiredBookingDiagnosticPhotos } from "../media/booking-diagnostic-photo.service.js";

let started = false;

export function startBookingDiagnosticPhotoCleanup(): void {
  if (started) return;
  started = true;
  cron.schedule("17 4 * * *", () => {
    void cleanupExpiredBookingDiagnosticPhotos().then((removed) => {
      if (removed > 0) logger.info({ removed }, "Expired diagnostic photo uploads cleaned");
    }).catch((error) => logger.error({ error }, "Expired diagnostic photo cleanup failed"));
  });
}