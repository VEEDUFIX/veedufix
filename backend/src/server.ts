import { createServer } from "http";
import { createApp } from "./app.js";
import { env } from "./config/env.js";
import { logger } from "./lib/logger.js";
import { attachRealtimeGateway } from "./lib/realtime.js";
import { startExpiredOfferRecovery } from "./modules/matching/matching.service.js";
import { startNoShowChecker } from "./modules/scheduler/no-show-checker.js";
import { startOpsExceptionSweep } from "./modules/scheduler/ops-exception-sweeper.js";
import { startPaymentReconciliation } from "./modules/scheduler/payment-reconciliation.js";
import { startLifecycleNotifications } from "./modules/scheduler/lifecycle-notifications.js";
import { startReferralCrediting } from "./modules/scheduler/referral-crediting.js";
import { startPayoutReleaser } from "./modules/scheduler/payout-releaser.js";

const app = createApp();
const server = createServer(app);

attachRealtimeGateway(server);
startExpiredOfferRecovery();
startNoShowChecker();
startOpsExceptionSweep();
startPaymentReconciliation();
startLifecycleNotifications();
startReferralCrediting();
startPayoutReleaser();

server.listen(env.PORT, () => {
  logger.info(`API listening on port ${env.PORT}`);
});
