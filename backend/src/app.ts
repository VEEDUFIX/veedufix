import compression from "compression";
import cors from "cors";
import express from "express";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import pinoHttp from "pino-http";
import { env } from "./config/env.js";
import { errorHandler, notFoundHandler } from "./middleware/error-handler.js";
import { logger } from "./lib/logger.js";
import { authRouter } from "./modules/auth/auth.routes.js";
import { healthRouter } from "./modules/health/health.routes.js";
import { usersRouter } from "./modules/users/users.routes.js";

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
  app.use(express.json({ limit: "2mb" }));
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
  app.use("/api/users", usersRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
