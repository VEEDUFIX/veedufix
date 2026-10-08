import { z } from "zod";

export const createPaymentOrderSchema = z.object({
  body: z
    .object({
      cityId: z.string().min(1).optional(),
      addressId: z.string().trim().min(1).optional(),
      couponCode: z.string().trim().min(1).max(64).optional(),
      items: z
        .array(
          z
            .object({
              serviceId: z.string().min(1),
              quantity: z.coerce.number().int().min(1).max(20).default(1),
              variantId: z.string().min(1).optional(),
              addonIds: z.array(z.string().min(1)).max(50).refine(
                (ids) => new Set(ids).size === ids.length,
                "Add-ons cannot be selected more than once"
              ).optional()
            })
            .strict()
        )
        .min(1)
        .max(20),
      bookingType: z.enum(["instant", "scheduled"]).default("instant"),
      scheduledFor: z.coerce.date().optional()
    })
    .strict()
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
