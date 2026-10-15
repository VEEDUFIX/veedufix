import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { createPaymentOrderSchema, verifyPaymentSchema } from "./payments.schemas.js";
import { createPaymentOrderHandler, paymentOrderStatusHandler, verifyPaymentHandler } from "./payments.controller.js";

export const paymentsRouter = Router();

const customerOnly = [requireAuth, requireRole("CUSTOMER")] as const;

paymentsRouter.get("/order-status/:bookingId/:orderId", ...customerOnly, paymentOrderStatusHandler);

paymentsRouter.post(
  "/create-order",
  ...customerOnly,
  validate(createPaymentOrderSchema),
  createPaymentOrderHandler
);

paymentsRouter.post(
  "/verify",
  ...customerOnly,
  validate(verifyPaymentSchema),
  verifyPaymentHandler
);

paymentsRouter.post(
  "/create-razorpay-order",
  ...customerOnly,
  validate(createPaymentOrderSchema),
  createPaymentOrderHandler
);

paymentsRouter.post(
  "/verify-payment",
  ...customerOnly,
  validate(verifyPaymentSchema),
  verifyPaymentHandler
);
