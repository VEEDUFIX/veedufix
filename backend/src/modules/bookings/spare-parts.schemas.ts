import { z } from "zod";

const bookingIdParams = z.object({
  params: z.object({ bookingId: z.string().min(1) })
});

// Worker submits spare parts request
export const submitSparePartsSchema = bookingIdParams.extend({
  body: z.object({
    items: z
      .array(
        z.object({
          label: z.string().min(1).max(200),
          amount: z.number().positive()
        })
      )
      .min(1, "At least one spare part is required"),
    receiptPhotoUrl: z.string().url().optional()
  })
});

// Customer initiates payment for spare parts
export const sparePartsPaymentOrderSchema = bookingIdParams;

// Customer verifies spare parts payment
export const verifySparePartsPaymentSchema = bookingIdParams.extend({
  body: z.object({
    razorpayOrderId: z.string().min(1),
    razorpayPaymentId: z.string().min(1),
    razorpaySignature: z.string().min(1)
  })
});

// Customer rejects spare parts request
export const rejectSparePartsSchema = bookingIdParams;
