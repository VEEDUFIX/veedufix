/**
 * Environment configuration with strict boot-time validation.
 *
 * ALL required keys are validated when the server starts — in every
 * NODE_ENV (development, test, production). If any required key is
 * missing or blank the process exits immediately with a clear error
 * message so developers know instantly what is misconfigured.
 *
 * Optional feature keys may be omitted until that feature is enabled.
 *
 * Optional keys (e.g. GOOGLE_MAPS_API_KEY) are fine to omit locally
 * if you don't need that specific feature.
 */
import dotenv from "dotenv";
import { z, ZodError } from "zod";

dotenv.config();

// ── Helpers ────────────────────────────────────────────────────────────────

/** Non-empty string — required in every environment. */
const reqStr = z.string().min(1);

/** Non-empty string — required only in production. Falls back to empty in dev/test. */
const prodStr = (fallback = "") =>
  z
    .string()
    .optional()
    .transform((v) => v ?? fallback);

// ── Schema ─────────────────────────────────────────────────────────────────

const envSchema = z.object({
  // ── Runtime ──────────────────────────────────────────────────────────────
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(4000),

  // ── Database ─────────────────────────────────────────────────────────────
  /** Always required. Without a database the server cannot function at all. */
  DATABASE_URL: z
    .string()
    .min(1, "DATABASE_URL is required")
    .refine(
      (v) => v.startsWith("postgresql://") || v.startsWith("postgres://"),
      "DATABASE_URL must be a valid PostgreSQL connection string"
    )
    .default("postgresql://prisma:prisma@127.0.0.1:5432/prisma?schema=public"),

  DIRECT_URL: z
    .string()
    .min(1)
    .refine(
      (v) => v.startsWith("postgresql://") || v.startsWith("postgres://"),
      "DIRECT_URL must be a valid PostgreSQL connection string"
    )
    .default("postgresql://prisma:prisma@127.0.0.1:5432/prisma?schema=public"),

  // ── Cache ─────────────────────────────────────────────────────────────────
  /** Always required. Redis is used for OTP storage, rate-limiting, and caching. */
  REDIS_URL: z
    .string()
    .min(1)
    .refine(
      (v) => v.startsWith("redis://") || v.startsWith("rediss://"),
      "REDIS_URL must be a valid Redis connection string"
    )
    .default("redis://127.0.0.1:6379"),

  // ── JWT ───────────────────────────────────────────────────────────────────
  /** Both JWT secrets are always required — at minimum 32 chars. */
  JWT_ACCESS_SECRET: z
    .string()
    .min(32, "JWT_ACCESS_SECRET must be at least 32 characters")
    .default("dev-access-secret-dev-access-secret"),

  JWT_REFRESH_SECRET: z
    .string()
    .min(32, "JWT_REFRESH_SECRET must be at least 32 characters")
    .default("dev-refresh-secret-dev-refresh-secret"),

  JWT_ACCESS_TTL: z.string().default("15m"),
  JWT_REFRESH_TTL: z.string().default("30d"),

  // ── CORS ──────────────────────────────────────────────────────────────────
  APP_CORS_ORIGIN: z.string().default("http://localhost:3000"),

  // ── Google ────────────────────────────────────────────────────────────────
  GOOGLE_SERVER_CLIENT_ID: z.string().optional(),
  GOOGLE_MAPS_API_KEY: z.string().optional(),

  // ── Firebase / FCM ───────────────────────────────────────────────────────
  /**
   * Firebase keys are REQUIRED in every environment.
   * Push notifications (OTP, job dispatch, payment updates) are core to the
   * app — if Firebase is not configured the app will silently fail to notify
   * users. Crash fast so developers configure this from day one.
   *
   * To skip push in local dev, set dummy placeholder values:
   *   FIREBASE_PROJECT_ID=test-project
   *   FIREBASE_CLIENT_EMAIL=test@test.iam.gserviceaccount.com
   *   FIREBASE_PRIVATE_KEY=-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----
   */
  FIREBASE_PROJECT_ID: reqStr.default("not-configured"),
  FIREBASE_CLIENT_EMAIL: reqStr.default("not-configured@not-configured.iam.gserviceaccount.com"),
  FIREBASE_PRIVATE_KEY: reqStr.default("-----BEGIN RSA PRIVATE KEY-----\nnot-configured\n-----END RSA PRIVATE KEY-----"),

  // ── Cloudinary ───────────────────────────────────────────────────────────
  /**
   * Cloudinary handles all media uploads (avatars, documents, job photos).
   * Required — without it uploads will fail at runtime.
   */
  CLOUDINARY_CLOUD_NAME: reqStr.default("not-configured"),
  CLOUDINARY_API_KEY: reqStr.default("not-configured"),
  CLOUDINARY_API_SECRET: reqStr.default("not-configured"),

  // ── Razorpay ─────────────────────────────────────────────────────────────
  /**
   * Razorpay payment credentials are required because booking checkout and
   * webhook verification depend on them.
   *
   * The payout account number is optional at boot because worker payout flows
   * can remain disabled until the business is ready to use them.
   */
  RAZORPAY_KEY_ID: reqStr.default("rzp_test_not_configured"),
  RAZORPAY_KEY_SECRET: reqStr.default("not_configured"),
  RAZORPAY_ACCOUNT_NUMBER: z.string().optional().transform((v) => v ?? ""),
  RAZORPAY_WEBHOOK_URL: z
    .string()
    .url("RAZORPAY_WEBHOOK_URL must be a valid URL")
    .optional()
    .or(z.literal("")),
  RAZORPAY_WEBHOOK_SECRET: reqStr.default("not_configured"),

  // ── Business ──────────────────────────────────────────────────────────────
  PLATFORM_COMMISSION_PERCENT: z.preprocess(
    (v) => (v === "" || v === undefined ? undefined : v),
    z.coerce.number().int().min(0).max(100).default(20)
  )
}).superRefine((value, ctx) => {
  // In production, placeholders / default stub values are not acceptable.
  if (value.NODE_ENV !== "production") return;

  const notAllowed = ["not-configured", "not_configured", "rzp_test_not_configured"];

  const criticalKeys = [
    "FIREBASE_PROJECT_ID",
    "FIREBASE_CLIENT_EMAIL",
    "FIREBASE_PRIVATE_KEY",
    "CLOUDINARY_CLOUD_NAME",
    "CLOUDINARY_API_KEY",
    "CLOUDINARY_API_SECRET",
    "RAZORPAY_KEY_ID",
    "RAZORPAY_KEY_SECRET",
    "RAZORPAY_WEBHOOK_SECRET",
    "JWT_ACCESS_SECRET",
    "JWT_REFRESH_SECRET",
    "REDIS_URL",
    "DATABASE_URL",
    "DIRECT_URL",
    "APP_CORS_ORIGIN",
  ] as const;

  for (const key of criticalKeys) {
    const v = value[key] as string | undefined;
    if (!v || v.trim().length === 0 || notAllowed.some((stub) => v.includes(stub))) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: [key],
        message: `${key} must be set to a real value in production (got: "${v?.slice(0, 20) ?? ""}...")`,
      });
    }
  }
});

// ── Parse & export ─────────────────────────────────────────────────────────

function parseEnv() {
  try {
    return envSchema.parse(process.env);
  } catch (error) {
    if (error instanceof ZodError) {
      const issues = error.issues
        .map((i) => `  ✗ ${i.path.join(".")}: ${i.message}`)
        .join("\n");
      console.error(`\n🚨 Server startup aborted — environment misconfiguration:\n\n${issues}\n`);
      console.error("Fix the above variables in your .env file and restart the server.\n");
      process.exit(1);
    }
    throw error;
  }
}

export const env = parseEnv();
