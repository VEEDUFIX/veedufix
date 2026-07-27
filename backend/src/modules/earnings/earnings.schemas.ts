import { z } from "zod";

const payoutStatusSchema = z.enum(["pending", "processing", "success", "failed"]);

const emptyObjectSchema = z.object({}).strict();

function isValidCalendarDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    return false;
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const parsed = new Date(year, month - 1, day);

  return (
    parsed.getFullYear() === year &&
    parsed.getMonth() === month - 1 &&
    parsed.getDate() === day
  );
}

const calendarDateSchema = z
  .string()
  .trim()
  .refine(isValidCalendarDate, {
    message: "Expected a valid date in YYYY-MM-DD format"
  })
  .transform((value) => {
    const [year, month, day] = value.split("-").map(Number);
    return new Date(year, month - 1, day);
  });

export const workerEarningsSummaryQuerySchema = z.object({
  body: emptyObjectSchema,
  query: emptyObjectSchema,
  params: emptyObjectSchema
});

export const workerEarningsTransactionsQuerySchema = z.object({
  body: emptyObjectSchema,
  query: z
    .object({
      fromDate: calendarDateSchema.optional(),
      toDate: calendarDateSchema.optional(),
      status: payoutStatusSchema.optional(),
      page: z.coerce.number().int().min(1).default(1),
      limit: z.coerce.number().int().min(1).max(100).default(20)
    })
    .strict()
    .superRefine((query, ctx) => {
      if (query.fromDate && query.toDate && query.fromDate.getTime() > query.toDate.getTime()) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["toDate"],
          message: "toDate must be the same as or later than fromDate"
        });
      }
    }),
  params: emptyObjectSchema
});
