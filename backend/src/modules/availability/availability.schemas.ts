import { z } from "zod";

const emptyObjectSchema = z.object({}).strict();

const timeSchema = z
  .string()
  .trim()
  .regex(/^([01]\d|2[0-3]):([0-5]\d)$/, "Time must use 24-hour HH:MM format");

const availabilitySlotSchema = z
  .object({
    dayOfWeek: z.number().int().min(0).max(6),
    startTime: timeSchema,
    endTime: timeSchema
  })
  .strict()
  .superRefine((slot, ctx) => {
    const [startHour, startMinute] = slot.startTime.split(":").map(Number);
    const [endHour, endMinute] = slot.endTime.split(":").map(Number);
    const startMinutes = startHour * 60 + startMinute;
    const endMinutes = endHour * 60 + endMinute;

    if (endMinutes <= startMinutes) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["endTime"],
        message: "endTime must be later than startTime"
      });
    }
  });

export const setWeeklyAvailabilitySchema = z.object({
  body: z.object({
    slots: z.array(availabilitySlotSchema).superRefine((slots, ctx) => {
      const byDay = new Map<number, Array<{ index: number; start: number; end: number }>>();
      slots.forEach((slot, index) => {
        const [startHour, startMinute] = slot.startTime.split(":").map(Number);
        const [endHour, endMinute] = slot.endTime.split(":").map(Number);
        const daySlots = byDay.get(slot.dayOfWeek) ?? [];
        daySlots.push({
          index,
          start: startHour * 60 + startMinute,
          end: endHour * 60 + endMinute
        });
        byDay.set(slot.dayOfWeek, daySlots);
      });

      for (const daySlots of byDay.values()) {
        daySlots.sort((left, right) => left.start - right.start);
        for (let index = 1; index < daySlots.length; index += 1) {
          if (daySlots[index]!.start < daySlots[index - 1]!.end) {
            ctx.addIssue({
              code: z.ZodIssueCode.custom,
              path: [daySlots[index]!.index, "startTime"],
              message: "Availability time slots on the same day cannot overlap"
            });
          }
        }
      }
    })
  }).strict(),
  query: emptyObjectSchema,
  params: emptyObjectSchema
});

export const listAvailabilitySchema = z.object({
  body: emptyObjectSchema,
  query: emptyObjectSchema,
  params: emptyObjectSchema
});

export const publicAvailabilityParamsSchema = z.object({
  body: emptyObjectSchema,
  query: emptyObjectSchema,
  params: z.object({
    workerId: z.string().trim().min(1)
  })
});

export const customerScheduleSlotsSchema = z.object({
  body: emptyObjectSchema,
  params: emptyObjectSchema,
  query: z.object({
    addressId: z.string().trim().min(1),
    serviceIds: z.string().trim().min(1).transform((value) => [...new Set(value.split(",").map((id) => id.trim()).filter(Boolean))]).pipe(z.array(z.string().min(1)).min(1).max(10)),
    startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine((value) => {
      const [year, month, day] = value.split("-").map(Number);
      const parsed = new Date(Date.UTC(year, month - 1, day));
      return parsed.getUTCFullYear() === year && parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === day;
    }, "startDate must be a valid calendar date"),
    days: z.coerce.number().int().min(1).max(7).default(7)
  }).strict()
});
