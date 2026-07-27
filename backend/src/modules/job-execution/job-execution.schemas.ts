import { z } from "zod";

const bookingIdParamsSchema = z.object({
  bookingId: z.string().min(1)
});

const otpSchema = z
  .string()
  .trim()
  .regex(/^\d{4}$/, "OTP must be a 4-digit code");

const jobPhotoTypeSchema = z.enum(["before", "after"]);

const checklistItemsSchema = z.union([z.array(z.unknown()), z.record(z.unknown())]);

export const generateArrivalOtpSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    workerLat: z.coerce.number().optional(),
    workerLng: z.coerce.number().optional()
  })
});

export const verifyArrivalOtpSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    otpInput: otpSchema
  })
});

export const bookingIdParamsOnlySchema = z.object({
  params: bookingIdParamsSchema
});

export const uploadJobPhotosSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    photoUrls: z.array(z.string().url()).min(1),
    type: jobPhotoTypeSchema
  })
});

export const updateChecklistSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    items: checklistItemsSchema
  })
});

export const requestCompletionOtpSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({})
});

export const verifyCompletionOtpSchema = z.object({
  params: bookingIdParamsSchema,
  body: z.object({
    otpInput: otpSchema
  })
});
