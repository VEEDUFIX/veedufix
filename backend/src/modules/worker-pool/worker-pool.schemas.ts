import { z } from "zod";

export const workerPoolQuerySchema = z.object({
  body: z.object({}).optional(),
  query: z.object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    cityId: z.string().trim().min(1).optional(),
    categoryId: z.string().trim().min(1).optional(),
    onlyAvailable: z.coerce.boolean().default(true)
  }),
  params: z.object({}).optional()
});

