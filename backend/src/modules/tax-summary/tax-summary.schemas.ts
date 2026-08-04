import { z } from "zod";

const dateRangeQueryShape = z.object({
  startDate: z.string().trim().min(1),
  endDate: z.string().trim().min(1)
});

export const taxSummaryGstQuerySchema = z.object({
  body: z.object({}).optional(),
  query: dateRangeQueryShape,
  params: z.object({}).optional()
});

export const taxSummaryRevenueQuerySchema = z.object({
  body: z.object({}).optional(),
  query: dateRangeQueryShape,
  params: z.object({}).optional()
});

export const taxSummaryAnnualQuerySchema = z.object({
  body: z.object({}).optional(),
  query: z.object({
    financialYear: z.string().trim().min(1)
  }),
  params: z.object({}).optional()
});

export const taxSummaryExportQuerySchema = z.object({
  body: z.object({}).optional(),
  query: dateRangeQueryShape,
  params: z.object({}).optional()
});
