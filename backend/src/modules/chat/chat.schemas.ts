import { z } from "zod";

export const getChatRoomParamsSchema = z.object({
  params: z.object({
    bookingId: z.string().min(1, "Booking ID is required")
  })
});

export const sendMessageSchema = z.object({
  params: z.object({
    bookingId: z.string().min(1, "Booking ID is required")
  }),
  body: z.object({
    content: z.string().min(1, "Message content is required").max(1000),
    attachments: z.array(
      z.object({
        url: z.string().url(),
        name: z.string().max(255).optional(),
        mimeType: z.string().max(120).optional(),
        size: z.number().int().nonnegative().optional(),
        kind: z.enum(["image", "file"]).default("file")
      })
    ).max(5).optional()
  })
});

export const markAsReadSchema = z.object({
  params: z.object({
    bookingId: z.string().min(1, "Booking ID is required")
  })
});
