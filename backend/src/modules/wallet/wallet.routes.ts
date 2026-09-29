import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { applyReferralSchema, requestPayoutSchema } from "./wallet.schemas.js";
import { applyReferralHandler, getWalletHandler, requestPayoutHandler } from "./wallet.controller.js";

export const walletRouter = Router();

walletRouter.use(requireAuth);

walletRouter.get("/", getWalletHandler);
walletRouter.post("/referral", validate(applyReferralSchema), applyReferralHandler);
walletRouter.post("/payout", requireRole("WORKER"), validate(requestPayoutSchema), requestPayoutHandler);
