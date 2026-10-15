import { z } from "zod";

const id = z.string().trim().min(1).max(128);
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine((value) => {
  const [year, month, day] = value.split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  return parsed.getUTCFullYear() === year && parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === day;
}, "Enter a valid calendar date");

export const createMaintenancePlanSchema = z.object({
  body: z.object({
    serviceId: id,
    variantId: id.optional(),
    addressId: id,
    intervalMonths: z.number().int().min(1).max(24),
    startAt: date,
    endAt: date.optional(),
    preferredTime: z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/).optional(),
    timezone: z.string().min(1).max(80).default("Asia/Kolkata")
}).strict().refine((body) => !body.endAt || body.endAt >= body.startAt, {
  message: "End date must be on or after the start date",
  path: ["endAt"]
})
});

export const maintenancePlanParamsSchema = z.object({ params: z.object({ planId: id }) });

export const maintenanceOccurrenceParamsSchema = z.object({
  params: z.object({ planId: id, occurrenceId: id })
});

export const rescheduleMaintenanceOccurrenceSchema = z.object({
  params: z.object({ planId: id, occurrenceId: id }),
  body: z.object({ dueAt: date }).strict()
});

export const adminMaintenancePlansQuerySchema = z.object({
  query: z.object({
    status: z.enum(["ACTIVE", "PAUSED", "CANCELLED"]).optional(),
    serviceId: id.optional()
  })
});
