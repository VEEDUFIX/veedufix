import { z } from "zod";

const refundIdParamsSchema = z.object({
  refundId: z.string().trim().min(1)
});

export const listRefundsQuerySchema = z.object({
  body: z.object({}).optional(),
  query: z.object({
    status: z.enum(["pending", "processed", "failed"]).optional(),
    workerId: z.string().trim().min(1).optional(),
    page: z.coerce.number().int().positive().default(1),
    pageSize: z.coerce.number().int().positive().max(100).default(20)
  }),
  params: z.object({}).optional()
});

export const retryRefundParamsSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: refundIdParamsSchema
});
