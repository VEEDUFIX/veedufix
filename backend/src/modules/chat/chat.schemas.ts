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
    content: z.string().min(1, "Message content is required").max(1000)
  })
});

export const markAsReadSchema = z.object({
  params: z.object({
    bookingId: z.string().min(1, "Booking ID is required")
  })
});
