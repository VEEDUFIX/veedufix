import { z } from 'zod';

export const requestCustomQuoteSchema = z.object({
  body: z.object({ notes: z.string().trim().max(500).optional() }),
  params: z.object({ bookingId: z.string().min(1) }),
  query: z.object({}).strict()
});

export const submitCustomQuoteSchema = z.object({
  body: z.object({
    amount: z.coerce.number().positive(),
    notes: z.string().trim().max(1000).optional(),
    itemized: z.array(z.object({
      label: z.string().min(1),
      qty: z.number().int().min(1).default(1),
      unitPrice: z.number().positive()
    })).optional()
  }),
  params: z.object({ bookingId: z.string().min(1) }),
  query: z.object({}).strict()
});

export const respondCustomQuoteSchema = z.object({
  body: z.object({ accept: z.boolean() }),
  params: z.object({ bookingId: z.string().min(1) }),
  query: z.object({}).strict()
});
