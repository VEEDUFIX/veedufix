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
    reason: z.string().trim().min(10).max(2000),
    issueCategory: z.string().trim().min(2).max(60).optional(),
    serviceId: z.string().trim().min(1).optional(),
    evidencePhotoIds: z.array(z.string().trim().min(1)).max(5).optional(),
    idempotencyKey: z.string().trim().min(8).max(120).optional()
  })
});

export const claimMessageSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    message: z.string().trim().min(2).max(2000),
    idempotencyKey: z.string().trim().min(8).max(120)
  })
});

export const claimReworkProposalSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    proposedAt: z.coerce.date(),
    message: z.string().trim().max(1000).optional(),
    idempotencyKey: z.string().trim().min(8).max(120)
  })
});

export const claimReworkCompletionSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    message: z.string().trim().min(3).max(1000),
    idempotencyKey: z.string().trim().min(8).max(120)
  })
});

export const claimResolutionConfirmationSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    confirmed: z.boolean(),
    message: z.string().trim().max(1000).optional(),
    idempotencyKey: z.string().trim().min(8).max(120)
  })
});

export const customerDisputeParamsSchema = z.object({
  params: bookingIdParamsSchema
});

export const listDisputesQuerySchema = z.object({
  query: z.object({
    city: z.string().trim().min(1).optional(),
    status: z.enum([
      "all",
      "open",
      "under_review",
      "refund_pending",
      "action_required",
      "approved",
      "closed",
      "resolved_rework",
      "resolved_refund",
      "resolved_rejected"
    ]).optional(),
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

export const updateDisputeClaimSchema = z.object({
  params: disputeIdParamsSchema,
  body: z.object({
    action: z.enum(["request_info", "approve_rework", "schedule_rework", "reject", "close", "internal_note"]),
    message: z.string().trim().min(3).max(2000),
    scheduledAt: z.coerce.date().optional(),
    visibility: z.enum(["CUSTOMER", "INTERNAL"]).optional()
  })
});
