import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { createPaymentOrderSchema, verifyPaymentSchema } from "./payments.schemas.js";
import { createPaymentOrderHandler, verifyPaymentHandler } from "./payments.controller.js";

export const paymentsRouter = Router();

const customerOnly = [requireAuth, requireRole("CUSTOMER")] as const;

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
