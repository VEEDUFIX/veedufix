import { z } from "zod";

const bookingIdParamsSchema = z.object({
  bookingId: z.string().trim().min(1)
});

export const dispatchBookingSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({}).optional(),
  query: z.object({}).optional()
});

export const jobOfferActionSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({}).optional(),
  query: z.object({}).optional()
});

