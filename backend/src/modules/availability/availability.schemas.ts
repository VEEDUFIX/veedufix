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
    slots: z.array(availabilitySlotSchema)
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
