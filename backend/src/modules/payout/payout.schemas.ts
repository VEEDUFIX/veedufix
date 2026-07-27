import { z } from "zod";

const payoutStatusSchema = z.enum(["pending", "processing", "success", "failed"]);

const listPayoutsQueryShape = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  status: payoutStatusSchema.optional(),
  workerId: z.string().trim().min(1).optional()
});

export const listPayoutsQuerySchema = z.object({
  body: z.object({}).optional(),
  query: listPayoutsQueryShape,
  params: z.object({}).optional()
});

export const retryPayoutParamsSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({
    payoutId: z.string().trim().min(1)
  })
});
