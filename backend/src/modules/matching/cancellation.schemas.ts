import { z } from "zod";

const bookingIdParamsSchema = z.object({
  bookingId: z.string().min(1)
});

export const cancelBookingSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    reason: z.string().trim().min(3).max(2000)
  })
});

