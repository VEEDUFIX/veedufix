import { createServer } from "http";
import { createApp } from "./app.js";
import { env } from "./config/env.js";
import { logger } from "./lib/logger.js";
import { attachRealtimeGateway } from "./lib/realtime.js";
import { startExpiredOfferRecovery } from "./modules/matching/matching.service.js";
import { startNoShowChecker } from "./modules/scheduler/no-show-checker.js";
import { startDisputeEscalation } from "./modules/scheduler/dispute-escalation.js";

const app = createApp();
const server = createServer(app);

attachRealtimeGateway(server);
startExpiredOfferRecovery();
startNoShowChecker();
startDisputeEscalation();

server.listen(env.PORT, () => {
  logger.info(`API listening on port ${env.PORT}`);
});
