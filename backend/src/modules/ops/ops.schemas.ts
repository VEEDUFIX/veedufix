import { z } from "zod";

const alertKindSchema = z.enum(["dispatch_failure", "payout_failure", "refund_failure", "payment_mismatch"]);
const alertSeveritySchema = z.enum(["low", "medium", "high", "critical"]);
const alertStatusSchema = z.enum(["open", "acknowledged", "resolved"]);

export const opsAlertListQuerySchema = z.object({
  query: z.object({
    type: alertKindSchema.optional(),
    severity: alertSeveritySchema.optional(),
    status: alertStatusSchema.optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(25)
  })
});
