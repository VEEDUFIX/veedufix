import { z } from "zod";

export const applyReferralSchema = z.object({
  body: z.object({
    referralCode: z.string().min(1, "Referral code is required")
  })
});

export const requestPayoutSchema = z.object({
  body: z.object({
    amount: z.number().finite().positive().multipleOf(0.01)
  })
});
