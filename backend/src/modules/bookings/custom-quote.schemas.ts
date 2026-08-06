import { z } from "zod";

const bookingIdParams = z.object({
  params: z.object({ bookingId: z.string().min(1) })
});

// Worker submits a quote after a site visit
export const submitCustomQuoteSchema = bookingIdParams.extend({
  body: z.object({
    items: z
      .array(
        z.object({
          label: z.string().min(1).max(200),
          amount: z.number().positive()
        })
      )
      .min(1, "At least one line item is required"),
    notes: z.string().max(1000).optional()
  })
});

// Customer accepts a quote
export const acceptCustomQuoteSchema = bookingIdParams;

// Customer rejects a quote
export const rejectCustomQuoteSchema = bookingIdParams;
