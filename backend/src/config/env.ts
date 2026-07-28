import dotenv from "dotenv";
import { z } from "zod";

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(4000),
  DATABASE_URL: z
    .string()
    .url()
    .or(z.string().startsWith("postgresql://"))
    .default("postgresql://prisma:prisma@127.0.0.1:5432/prisma?schema=public"),
  DIRECT_URL: z
    .string()
    .url()
    .or(z.string().startsWith("postgresql://"))
    .default("postgresql://prisma:prisma@127.0.0.1:5432/prisma?schema=public"),
  REDIS_URL: z
    .string()
    .url()
    .or(z.string().startsWith("redis://"))
    .default("redis://127.0.0.1:6379"),
  JWT_ACCESS_SECRET: z.string().min(32).default("dev-access-secret-dev-access-secret"),
  JWT_REFRESH_SECRET: z.string().min(32).default("dev-refresh-secret-dev-refresh-secret"),
  JWT_ACCESS_TTL: z.string().default("15m"),
  JWT_REFRESH_TTL: z.string().default("30d"),
  APP_CORS_ORIGIN: z.string().default("http://localhost:3000"),
  GOOGLE_SERVER_CLIENT_ID: z.string().optional(),
  FIREBASE_PROJECT_ID: z.string().optional(),
  FIREBASE_CLIENT_EMAIL: z.string().optional(),
  FIREBASE_PRIVATE_KEY: z.string().optional(),
  CLOUDINARY_CLOUD_NAME: z.string().optional(),
  CLOUDINARY_API_KEY: z.string().optional(),
  CLOUDINARY_API_SECRET: z.string().optional(),
  RAZORPAY_KEY_ID: z.string().optional(),
  RAZORPAY_KEY_SECRET: z.string().optional(),
  RAZORPAY_ACCOUNT_NUMBER: z.string().optional(),
  RAZORPAY_WEBHOOK_SECRET: z.string().optional(),
  PLATFORM_COMMISSION_PERCENT: z.preprocess(
    (value) => (value === "" || value === undefined ? undefined : value),
    z.coerce.number().int().min(0).max(100).default(20)
  )
}).superRefine((value, ctx) => {
  if (value.NODE_ENV !== "production" || process.env.RENDER === "true") {
    return;
  }

  const requiredKeys: Array<keyof typeof value> = [
    "APP_CORS_ORIGIN",
    "DIRECT_URL",
    "DATABASE_URL",
    "FIREBASE_CLIENT_EMAIL",
    "FIREBASE_PRIVATE_KEY",
    "FIREBASE_PROJECT_ID",
    "GOOGLE_SERVER_CLIENT_ID",
    "JWT_ACCESS_SECRET",
    "JWT_REFRESH_SECRET",
    "RAZORPAY_KEY_ID",
    "RAZORPAY_KEY_SECRET",
    "RAZORPAY_WEBHOOK_SECRET",
    "REDIS_URL",
    "CLOUDINARY_CLOUD_NAME",
    "CLOUDINARY_API_KEY",
    "CLOUDINARY_API_SECRET",
    "RAZORPAY_ACCOUNT_NUMBER"
  ];

  for (const key of requiredKeys) {
    const rawValue = value[key];
    if (typeof rawValue === "string" && rawValue.trim().length === 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: [key],
        message: `${String(key)} is required in production`
      });
    }
  }
});

export const env = envSchema.parse(process.env);
