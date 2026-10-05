import { z } from "zod";

export const submitReviewSchema = z.object({
  body: z.object({
    bookingId: z.string().min(1, "Booking ID is required"),
    rating: z.number().int().min(1).max(5),
    comment: z.string().trim().max(500, "Review comments must be 500 characters or fewer").optional(),
    mediaUrls: z.array(z.string()).optional()
  })
});

export const getWorkerReviewsSchema = z.object({
  params: z.object({
    workerId: z.string().min(1, "Worker ID is required")
  }),
  query: z.object({
    page: z.string().optional(),
    limit: z.string().optional()
  })
});

export const reportReviewSchema = z.object({
  params: z.object({ reviewId: z.string().min(1) }),
  body: z.object({ reason: z.string().trim().min(10).max(500) })
});

export const listReviewReportsSchema = z.object({
  query: z.object({
    page: z.coerce.number().int().positive().default(1),
    pageSize: z.coerce.number().int().positive().max(100).default(20)
  })
});

export const moderateReviewSchema = z.object({
  params: z.object({ reviewId: z.string().min(1) }),
  body: z.object({ status: z.enum(["published", "hidden"]) })
});

export const dismissReviewReportSchema = z.object({
  params: z.object({ reportId: z.string().min(1) })
});

export const workerReviewResponseSchema = z.object({
  params: z.object({ reviewId: z.string().min(1) }),
  body: z.object({ response: z.string().trim().min(3).max(500) })
});
