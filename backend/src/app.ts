import compression from "compression";
import cors from "cors";
import express from "express";
import type { Request } from "express";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import pinoHttp from "pino-http";
import { env } from "./config/env.js";
import { errorHandler, notFoundHandler } from "./middleware/error-handler.js";
import { logger } from "./lib/logger.js";
import { authRouter } from "./modules/auth/auth.routes.js";
import { catalogRouter, adminCatalogRouter } from "./modules/catalog/catalog.routes.js";
import { disputeRouter } from "./modules/dispute/dispute.routes.js";
import { cancellationRouter } from "./modules/matching/cancellation.routes.js";
import { opsRouter, adminAlertsRouter } from "./modules/ops/ops.routes.js";
import { jobExecutionRouter } from "./modules/job-execution/job-execution.routes.js";
import { healthRouter } from "./modules/health/health.routes.js";
import { mediaRouter } from "./modules/media/media.routes.js";
import { matchingRouter } from "./modules/matching/matching.routes.js";
import { addressRouter } from "./modules/address/address.routes.js";
import { availabilityRouter } from "./modules/availability/availability.routes.js";
import { paymentsRouter } from "./modules/payments/payments.routes.js";
import { payoutRouter } from "./modules/payout/payout.routes.js";
import { earningsRouter } from "./modules/earnings/earnings.routes.js";
import { refundRouter } from "./modules/refund/refund.routes.js";
import {
  adminWorkerDirectoryRouter,
  adminWorkerReviewRouter,
  workerOnboardingRouter
} from "./modules/worker-onboarding/worker-onboarding.routes.js";
import { workerPoolRouter } from "./modules/worker-pool/worker-pool.routes.js";
import { uploadRouter } from "./modules/upload/upload.routes.js";
import { webhooksRouter } from "./modules/webhooks/webhooks.routes.js";
import { usersRouter } from "./modules/users/users.routes.js";
import { adminAnalyticsRouter } from "./modules/analytics/analytics.routes.js";
import { chatRouter } from "./modules/chat/chat.routes.js";
import { reviewsRouter } from "./modules/reviews/reviews.routes.js";
import { walletRouter } from "./modules/wallet/wallet.routes.js";
import { aiRouter } from "./modules/ai/ai.routes.js";
import { supportRouter } from "./modules/support/support.routes.js";
import { adminSearchRouter } from "./modules/admin/admin-search.routes.js";
import { adminAuditRouter } from "./modules/admin/admin-audit.routes.js";
import { adminCustomersRouter, adminBookingsRouter } from "./modules/users/admin-users.routes.js";
import { adminCouponsRouter } from "./modules/catalog/admin-coupons.routes.js";
import { adminReportsRouter } from "./modules/analytics/admin-reports.routes.js";
import { adminNotificationsRouter } from "./modules/admin/admin-notifications.routes.js";
import { deviceTokenRouter } from "./modules/device-token/device-token.routes.js";
import { invoiceRouter } from "./modules/invoice/invoice.routes.js";
import { adminServiceAreaRouter, serviceAreaRouter } from "./modules/service-area/service-area.routes.js";
import { adminPlatformSettingsRouter } from "./modules/platform-settings/platform-settings.routes.js";
import { taxSummaryRouter } from "./modules/tax-summary/tax-summary.routes.js";
import { customQuoteRouter } from "./modules/bookings/custom-quote.routes.js";
import { sparePartsRouter } from "./modules/bookings/spare-parts.routes.js";

export function createApp() {
  const app = express();

  app.use(
    pinoHttp({
      logger
    })
  );
  app.use(helmet());
  app.use(
    cors({
      origin: env.APP_CORS_ORIGIN.split(",").map((origin) => origin.trim()),
      credentials: true
    })
  );
  app.use(
    express.json({
      limit: "2mb",
      verify: (request, _response, buffer) => {
        (request as Request & { rawBody?: string }).rawBody = buffer.toString("utf8");
      }
    })
  );
  app.use(express.urlencoded({ extended: true }));
  app.use(compression());
  app.use(
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit: env.NODE_ENV === "production" ? 100 : 1000,
      standardHeaders: true,
      legacyHeaders: false
    })
  );

  app.get("/api", (_request, response) => {
    response.status(200).json({
      message: "Local Services Marketplace API",
      version: "0.1.0"
    });
  });

  app.use("/api/health", healthRouter);
  app.use("/api/auth", authRouter);
  app.use("/api/catalog", catalogRouter);
  app.use("/api/admin/catalog", adminCatalogRouter);
  app.use("/api", disputeRouter);
  app.use("/api", cancellationRouter);
  app.use("/api/worker/onboarding", workerOnboardingRouter);
  app.use("/api/admin/worker-review", adminWorkerReviewRouter);
  app.use("/api/admin/workers", adminWorkerDirectoryRouter);
  app.use("/api/admin/worker-pool", workerPoolRouter);
  app.use("/api/admin/ops", opsRouter);
  app.use("/api/admin/alerts", adminAlertsRouter);
  app.use("/api", matchingRouter);
  app.use("/api", jobExecutionRouter);
  app.use("/api/media", mediaRouter);
  app.use("/api/uploads", uploadRouter);
  app.use("/uploads", uploadRouter);
  app.use("/api/payments", paymentsRouter);
  app.use("/api", addressRouter);
  app.use("/api", serviceAreaRouter);
  app.use("/api", availabilityRouter);
  app.use("/api", earningsRouter);
  app.use("/api/admin/payouts", payoutRouter);
  app.use("/api/admin/refunds", refundRouter);
  app.use("/api/admin/analytics", adminAnalyticsRouter);
  app.use("/api/admin/customers", adminCustomersRouter);
  app.use("/api/admin/bookings", adminBookingsRouter);
  app.use("/api/admin/coupons", adminCouponsRouter);
  app.use("/api/admin/reports", adminReportsRouter);
  app.use("/api/admin/tax-summary", taxSummaryRouter);
  app.use("/api/admin", adminServiceAreaRouter);
  app.use("/api/admin/platform-settings", adminPlatformSettingsRouter);
  app.use("/api/admin", adminSearchRouter);
  app.use("/api/admin", adminAuditRouter);
  app.use("/api/admin/notifications", adminNotificationsRouter);
  app.use("/api/webhooks", webhooksRouter);
  app.use("/api/users", usersRouter);
  app.use("/api/chat", chatRouter);
  app.use("/api/reviews", reviewsRouter);
  app.use("/api/wallet", walletRouter);
  app.use("/api/ai", aiRouter);
  app.use("/api", supportRouter);
  app.use("/api/device-tokens", deviceTokenRouter);
  app.use("/api", invoiceRouter);
  app.use("/api", customQuoteRouter);
  app.use("/api", sparePartsRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
