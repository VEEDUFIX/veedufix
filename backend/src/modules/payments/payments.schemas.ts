import { z } from "zod";

export const createPaymentOrderSchema = z.object({
  body: z
    .object({
      amountPaise: z.number().int().positive().min(100),
      description: z.string().min(3).max(160),
      bookingType: z.enum(["instant", "scheduled"]).default("instant"),
      scheduledFor: z.coerce.date().optional()
    })
    .superRefine((body, ctx) => {
      if (body.bookingType === "scheduled") {
        if (!body.scheduledFor) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ["scheduledFor"],
            message: "scheduledFor is required for scheduled bookings"
          });
          return;
        }

        if (body.scheduledFor.getTime() <= Date.now()) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ["scheduledFor"],
            message: "scheduledFor must be in the future"
          });
        }
        return;
      }

      if (body.scheduledFor) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["scheduledFor"],
          message: "scheduledFor is only allowed for scheduled bookings"
        });
      }
    })
});

export const verifyPaymentSchema = z.object({
  body: z.object({
    bookingId: z.string().min(1),
    razorpayOrderId: z.string().min(1),
    razorpayPaymentId: z.string().min(1),
    razorpaySignature: z.string().min(1)
  })
});
