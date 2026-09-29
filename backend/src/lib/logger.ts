import pino from "pino";

export const logger = pino({
  level: process.env.NODE_ENV === "production" ? "info" : "debug",
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.cookie",
      "req.headers.set-cookie",
      'req.headers["proxy-authorization"]',
      'req.headers["x-api-key"]',
      'req.headers["x-auth-token"]'
    ],
    censor: "[REDACTED]"
  }
});
