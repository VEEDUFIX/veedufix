import { z } from "zod";

export const submitReviewSchema = z.object({
  body: z.object({
    bookingId: z.string().min(1, "Booking ID is required"),
    rating: z.number().int().min(1).max(5),
    comment: z.string().optional(),
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
