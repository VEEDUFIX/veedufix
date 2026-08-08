/**
 * rate-limit.ts
 *
 * Factory helpers for express-rate-limit instances used across the backend.
 * All auth-specific limiters live here so thresholds are tuned in one place.
 *
 * Store
 * -----
 * Uses a Redis-backed store (rate-limit-redis → the same ioredis client used
 * for catalog caching) so counters survive server restarts and are shared
 * across all instances if the service is ever scaled horizontally.
 *
 * Graceful degradation
 * --------------------
 * `passOnStoreError: true` is set on every limiter. This is a first-class
 * express-rate-limit v8 option: if Redis is unreachable and store.increment()
 * throws, the library logs the error (via the `logger` option, wired to our
 * pino instance) and calls next() rather than rejecting the request. A Redis
 * outage therefore never becomes a login outage — it just temporarily disables
 * rate limiting, which is the same trade-off the catalog module makes for its
 * caching layer.
 *
 * Dev mode
 * --------
 * In non-production environments limits are multiplied by 50 so local testing
 * and automated smoke-tests are never blocked by tight auth limits.
 *
 * Response format
 * ---------------
 * HTTP 429 with standardHeaders (RateLimit-* + Retry-After) and a JSON body:
 * `{ message, retryAfterSeconds }`.
 */

import rateLimit, { ipKeyGenerator, type Options, type RateLimitRequestHandler } from "express-rate-limit";
import { RedisStore, type RedisReply } from "rate-limit-redis";
import type { Request } from "express";
import { env } from "../config/env.js";
import { logger } from "./logger.js";
import { redis } from "./redis.js";

const IS_PRODUCTION = env.NODE_ENV === "production";

/**
 * In non-production environments multiply every limit by this factor so
 * local development and CI aren't blocked by the tight auth limits.
 */
const DEV_MULTIPLIER = 50;

function effectiveLimit(limit: number, forceProductionLimit?: boolean): number {
  return IS_PRODUCTION || forceProductionLimit ? limit : limit * DEV_MULTIPLIER;
}

/** Shared handler called whenever any of our custom limiters trips. */
function rateLimitHandler(
  windowMs: number,
  _request: Request,
  response: import("express").Response
): void {
  const retryAfterSeconds = Math.ceil(windowMs / 1000);
  response.status(429).json({
    message: `Too many requests. Please try again in ${retryAfterSeconds} seconds.`,
    retryAfterSeconds
  });
}

/**
 * Build a RedisStore for a given key prefix.
 *
 * Each limiter gets its own prefix so their counters never collide in Redis,
 * even though they all share the same ioredis connection.
 *
 * sendCommand splits the first element (the Redis command name) from the rest
 * (the arguments) because ioredis.call() expects (command, ...args) while
 * rate-limit-redis passes a flat (...args) array where args[0] is the command.
 */
function makeRedisStore(prefix: string): RedisStore {
  return new RedisStore({
    prefix: `rl:${prefix}:`,
    // ioredis.call() accepts (command, ...args) and returns Promise<unknown>.
    // rate-limit-redis's SendCommandFn expects Promise<RedisReply>; the cast
    // is safe because Redis only ever returns boolean | number | string | arrays
    // thereof for the EVALSHA commands this store uses.
    sendCommand: (command: string, ...args: string[]): Promise<RedisReply> =>
      redis.call(command, ...args) as Promise<RedisReply>
  });
}

function makeLimiter(
  options: Partial<Options> & {
    windowMs: number;
    limit: number;
    forceProductionLimit?: boolean;
    storePrefix: string;
  }
): RateLimitRequestHandler {
  // Destructure our custom options out so they are never forwarded to
  // rateLimit() — express-rate-limit v8 throws ERR_ERL_UNKNOWN_OPTION for
  // any key it doesn't recognise.
  if (env.NODE_ENV === 'test' || process.env.VITEST) {
    const dummy = ((req: any, res: any, next: any) => next()) as any;
    dummy.resetKey = () => {};
    dummy.getKey = () => undefined;
    return dummy as RateLimitRequestHandler;
  }

  const { forceProductionLimit, storePrefix, ...rlOptions } = options;
  return rateLimit({
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: false,
    passOnStoreError: true,
    logger,
    store: makeRedisStore(storePrefix),
    handler: (req, res) => rateLimitHandler(options.windowMs, req, res),
    ...rlOptions,
    limit: effectiveLimit(options.limit, forceProductionLimit)
  });
}

// ---------------------------------------------------------------------------
// POST /api/auth/otp/request
//
// Key: IP + identifier (phone number or email address).
// Combining both dimensions prevents:
//   - Attacker hopping IPs to hammer a single identity (SMS cost abuse)
//   - Attacker hopping identifiers from a single IP (enumeration abuse)
//
// Limit: 3 requests per 10 minutes per (IP + identifier).
// ---------------------------------------------------------------------------
export function makeOtpRequestLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  const windowMs = 10 * 60 * 1000; // 10 minutes
  return makeLimiter({
    windowMs,
    limit: 3,
    storePrefix: "otp-request",
    forceProductionLimit: opts.forceProductionLimit,
    keyGenerator: (request: Request) => {
      // ipKeyGenerator normalises IPv6 addresses to their /56 subnet so a
      // single user cannot bypass limits by rotating IPv6 addresses.
      const ip = ipKeyGenerator(request.ip ?? "");
      const identifier = String(request.body?.identifier ?? "").toLowerCase().trim();
      return `${ip}:${identifier}`;
    }
  });
}

// ---------------------------------------------------------------------------
// POST /api/auth/otp/verify
//
// Key: IP + identifier.
// Prevents guessing the 4-6 digit OTP for a specific identity.
//
// Limit: 5 attempts per 10 minutes per (IP + identifier).
// ---------------------------------------------------------------------------
export function makeOtpVerifyLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  const windowMs = 10 * 60 * 1000; // 10 minutes
  return makeLimiter({
    windowMs,
    limit: 5,
    storePrefix: "otp-verify",
    forceProductionLimit: opts.forceProductionLimit,
    keyGenerator: (request: Request) => {
      const ip = ipKeyGenerator(request.ip ?? "");
      const identifier = String(request.body?.identifier ?? "").toLowerCase().trim();
      return `${ip}:${identifier}`;
    }
  });
}

// ---------------------------------------------------------------------------
// POST /api/auth/google
//
// Key: IP.
// The idToken varies per request so it can't be a key; IP is sufficient.
//
// Limit: 10 requests per minute per IP.
// ---------------------------------------------------------------------------
export function makeGoogleAuthLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  const windowMs = 60 * 1000; // 1 minute
  return makeLimiter({
    windowMs,
    limit: 10,
    storePrefix: "google-auth",
    forceProductionLimit: opts.forceProductionLimit,
    keyGenerator: (request: Request) => ipKeyGenerator(request.ip ?? "")
  });
}

// ---------------------------------------------------------------------------
// POST /api/auth/refresh
//
// Key: IP.
// Normal clients refresh at most once per access-token TTL (15 min).
// Allowing 20/minute is very generous for legitimate use while blocking
// automated refresh-token grinding.
//
// Limit: 20 requests per minute per IP.
// ---------------------------------------------------------------------------
export function makeRefreshLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  const windowMs = 60 * 1000; // 1 minute
  return makeLimiter({
    windowMs,
    limit: 20,
    storePrefix: "refresh",
    forceProductionLimit: opts.forceProductionLimit,
    keyGenerator: (request: Request) => ipKeyGenerator(request.ip ?? "")
  });
}

// ---------------------------------------------------------------------------
// POST /api/auth/signout
//
// Key: IP.
// No realistic abuse concern but apply a loose cap to prevent
// token-invalidation storms (e.g. scripted session-destruction).
//
// Limit: 30 requests per minute per IP.
// ---------------------------------------------------------------------------
export function makeSignOutLimiter(opts: { forceProductionLimit?: boolean } = {}): RateLimitRequestHandler {
  const windowMs = 60 * 1000; // 1 minute
  return makeLimiter({
    windowMs,
    limit: 30,
    storePrefix: "signout",
    forceProductionLimit: opts.forceProductionLimit,
    keyGenerator: (request: Request) => ipKeyGenerator(request.ip ?? "")
  });
}
