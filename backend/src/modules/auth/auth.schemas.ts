import { z } from "zod";

export const requestOtpSchema = z.object({
  body: z.object({
    channel: z.enum(["PHONE", "EMAIL"]),
    identifier: z.string().min(3).max(128)
  })
});

export const verifyOtpSchema = z.object({
  body: z.object({
    channel: z.enum(["PHONE", "EMAIL"]),
    identifier: z.string().min(3).max(128),
    otp: z.string().min(4).max(8),
    name: z.string().min(2).max(120).optional(),
    referralCode: z.string().optional()
  })
});

export const refreshTokenSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(20)
  })
});

export const authProviderSchema = z.object({
  body: z.object({
    provider: z.enum(["GOOGLE"]),
    idToken: z.string().min(20)
  })
});

export const signOutSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(20)
  })
});

export const sessionIdParamsSchema = z.object({
  params: z.object({
    sessionId: z.string().min(1)
  })
});
