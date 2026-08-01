import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  makeGoogleAuthLimiter,
  makeOtpRequestLimiter,
  makeOtpVerifyLimiter,
  makeRefreshLimiter,
  makeSignOutLimiter
} from "../../lib/rate-limit.js";
import {
  authProviderSchema,
  refreshTokenSchema,
  requestOtpSchema,
  sessionIdParamsSchema,
  signOutSchema,
  verifyOtpSchema
} from "./auth.schemas.js";
import {
  googleAuthHandler,
  listSessionsHandler,
  refreshTokenHandler,
  requestOtpHandler,
  revokeAllSessionsHandler,
  revokeSessionHandler,
  signOutHandler,
  verifyOtpHandler
} from "./auth.controller.js";

export const authRouter = Router();

// Rate limiters are instantiated once at module load and shared across all
// requests to the same endpoint.  Instantiating here (rather than inline)
// keeps the limiter state consistent across requests.
//
// Middleware order: validate → rateLimiter → handler
//   validate() runs first so req.body is Zod-parsed before the limiter's
//   keyGenerator reads req.body.identifier.
const otpRequestLimiter = makeOtpRequestLimiter();
const otpVerifyLimiter = makeOtpVerifyLimiter();
const googleAuthLimiter = makeGoogleAuthLimiter();
const refreshLimiter = makeRefreshLimiter();
const signOutLimiter = makeSignOutLimiter();

// POST /api/auth/otp/request
// Limit: 3 req / 10 min per (IP + identifier)  — prevents OTP spam / SMS-cost abuse
authRouter.post("/otp/request", validate(requestOtpSchema), otpRequestLimiter, requestOtpHandler);

// POST /api/auth/otp/verify
// Limit: 5 req / 10 min per (IP + identifier)  — prevents OTP brute-force guessing
authRouter.post("/otp/verify", validate(verifyOtpSchema), otpVerifyLimiter, verifyOtpHandler);

// POST /api/auth/google
// Limit: 10 req / min per IP  — general abuse protection for token exchange
authRouter.post("/google", validate(authProviderSchema), googleAuthLimiter, googleAuthHandler);

// POST /api/auth/refresh
// Limit: 20 req / min per IP  — prevents automated refresh-token grinding
authRouter.post("/refresh", validate(refreshTokenSchema), refreshLimiter, refreshTokenHandler);

// POST /api/auth/signout
// Limit: 30 req / min per IP  — loose cap against scripted session-destruction
authRouter.post("/signout", validate(signOutSchema), signOutLimiter, signOutHandler);
authRouter.get("/sessions", requireAuth, listSessionsHandler);
authRouter.delete("/sessions", requireAuth, revokeAllSessionsHandler);
authRouter.delete("/sessions/:sessionId", requireAuth, validate(sessionIdParamsSchema), revokeSessionHandler);
