import { z } from "zod";

const jobPhotoType = z.enum(["before", "after"]);

export const uploadSignatureSchema = z.object({
  body: z.object({
    bookingId: z.string().min(1),
    type: jobPhotoType
  })
});

export const uploadJobPhotoSchema = z.object({
  body: z.object({
    bookingId: z.string().min(1),
    type: jobPhotoType
  })
});

export const confirmJobPhotoSchema = z.object({
  body: z.object({
    bookingId: z.string().min(1),
    type: jobPhotoType,
    secureUrl: z.string().url(),
    publicId: z.string().min(1),
    folder: z.string().min(1).optional(),
    bytes: z.coerce.number().int().nonnegative().optional(),
    format: z.string().min(1).optional()
  })
});
