import { Router } from "express";
import { prisma } from "../../lib/prisma.js";
import { redis } from "../../lib/redis.js";
import { logger } from "../../lib/logger.js";

export const healthRouter = Router();

healthRouter.get("/", async (_request, response) => {
  const status: any = {
    service: "local-services-marketplace-backend",
    timestamp: new Date().toISOString(),
    postgres: "down",
    redis: "down"
  };

  let isHealthy = true;

  try {
    // Deep check 1: Postgres
    await prisma.$queryRawUnsafe("SELECT 1");
    status.postgres = "up";
  } catch (error) {
    logger.error({ error }, "Health check failed: Postgres");
    isHealthy = false;
  }

  try {
    // Deep check 2: Redis
    await redis.ping();
    status.redis = "up";
  } catch (error) {
    logger.error({ error }, "Health check failed: Redis");
    isHealthy = false;
  }

  status.ok = isHealthy;

  response.status(isHealthy ? 200 : 503).json(status);
});
