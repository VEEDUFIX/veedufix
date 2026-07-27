import { z } from "zod";

const bookingIdParamsSchema = z.object({
  bookingId: z.string().min(1)
});

const disputeIdParamsSchema = z.object({
  disputeId: z.string().min(1)
});

export const raiseDisputeSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    reason: z.string().trim().min(10).max(2000)
  })
});

export const listDisputesQuerySchema = z.object({
  query: z.object({
    city: z.string().trim().min(1).optional(),
    page: z.coerce.number().int().positive().default(1),
    pageSize: z.coerce.number().int().positive().max(100).default(20)
  })
});

export const disputeIdParamsOnlySchema = z.object({
  params: disputeIdParamsSchema
});

export const resolveDisputeSchema = z.object({
  params: disputeIdParamsSchema,
  body: z.object({
    resolution: z.enum(["refund", "reject"]),
    note: z.string().trim().min(3).max(2000)
  })
});
