import { isIP } from "node:net";
import rateLimit, { ipKeyGenerator, type Options, type RateLimitRequestHandler } from "express-rate-limit";
import { RedisStore, type RedisReply } from "rate-limit-redis";
import type { Request } from "express";
import { env } from "../config/env.js";
import { logger } from "./logger.js";
import { redis } from "./redis.js";

const isProduction = env.NODE_ENV === "production";

function createStore(prefix: string): RedisStore {
  return new RedisStore({
    prefix: `rl:${prefix}:`,
    sendCommand: (command: string, ...args: string[]): Promise<RedisReply> =>
      redis.call(command, ...args) as Promise<RedisReply>
  });
}

function createLimiter(options: Partial<Options> & {
  windowMs: number;
  limit: number;
  storePrefix: string;
  forceProductionLimit?: boolean;
}): RateLimitRequestHandler {
  if (env.NODE_ENV === "test" || process.env.VITEST) {
    const passthrough = ((_request: unknown, _response: unknown, next: () => void) => next()) as RateLimitRequestHandler;
    return passthrough;
  }

  const { storePrefix, forceProductionLimit, ...rateLimitOptions } = options;
  return rateLimit({
    standardHeaders: true,
    legacyHeaders: false,
    passOnStoreError: true,
    logger,
    store: createStore(storePrefix),
    handler: (_request, response) => {
      const retryAfterSeconds = Math.ceil(options.windowMs / 1000);
      response.status(429).json({ message: "Too many requests. Please try again later.", retryAfterSeconds });
    },
    ...rateLimitOptions,
    limit: isProduction || forceProductionLimit ? options.limit : options.limit * 50
  });
}

export function clientIpKey(request: Request): string {
  const forwardedFor = request.headers["x-forwarded-for"];
  const firstForwardedAddress = (Array.isArray(forwardedFor)
    ? forwardedFor[0]
    : forwardedFor
  )?.split(",", 1)[0]?.trim();
  const clientAddress = firstForwardedAddress && isIP(firstForwardedAddress)
    ? firstForwardedAddress
    : request.ip ?? "";

  return ipKeyGenerator(clientAddress);
}

export function makeOtpRequestLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  return createLimiter({
    windowMs: 10 * 60 * 1000,
    limit: 3,
    storePrefix: "otp-request",
    forceProductionLimit: opts.forceProductionLimit,
    keyGenerator: (request: Request) => `${clientIpKey(request)}:${String(request.body?.identifier ?? "").trim().toLowerCase()}`
  });
}

export function makeOtpVerifyLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  return createLimiter({
    windowMs: 10 * 60 * 1000,
    limit: 5,
    storePrefix: "otp-verify",
    forceProductionLimit: opts.forceProductionLimit,
    keyGenerator: (request: Request) => `${clientIpKey(request)}:${String(request.body?.identifier ?? "").trim().toLowerCase()}`
  });
}

export function makeGoogleAuthLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  return createLimiter({ windowMs: 60_000, limit: 10, storePrefix: "google-auth", forceProductionLimit: opts.forceProductionLimit, keyGenerator: clientIpKey });
}

export function makeFirebaseAuthLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  return createLimiter({ windowMs: 60_000, limit: 10, storePrefix: "firebase-auth", forceProductionLimit: opts.forceProductionLimit, keyGenerator: clientIpKey });
}

export function makeRefreshLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  return createLimiter({ windowMs: 60_000, limit: 20, storePrefix: "refresh", forceProductionLimit: opts.forceProductionLimit, keyGenerator: clientIpKey });
}

export function makeSignOutLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  return createLimiter({ windowMs: 60_000, limit: 30, storePrefix: "signout", forceProductionLimit: opts.forceProductionLimit, keyGenerator: clientIpKey });
}

export function makeAiChatLimiter(): RateLimitRequestHandler {
  return createLimiter({
    windowMs: 60_000,
    limit: 20,
    storePrefix: "ai-chat",
    keyGenerator: (request: Request) => {
      const userId = (request as Request & { auth?: { userId?: string } }).auth?.userId;
      return userId ? `user:${userId}` : clientIpKey(request);
    }
  });
}
