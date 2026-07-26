import { Router } from "express";
import { validate } from "../../middleware/validate.js";
import {
  authProviderSchema,
  refreshTokenSchema,
  requestOtpSchema,
  signOutSchema,
  verifyOtpSchema
} from "./auth.schemas.js";
import {
  googleAuthHandler,
  refreshTokenHandler,
  requestOtpHandler,
  signOutHandler,
  verifyOtpHandler
} from "./auth.controller.js";

export const authRouter = Router();

authRouter.post("/otp/request", validate(requestOtpSchema), requestOtpHandler);
authRouter.post("/otp/verify", validate(verifyOtpSchema), verifyOtpHandler);
authRouter.post("/google", validate(authProviderSchema), googleAuthHandler);
authRouter.post("/refresh", validate(refreshTokenSchema), refreshTokenHandler);
authRouter.post("/signout", validate(signOutSchema), signOutHandler);
