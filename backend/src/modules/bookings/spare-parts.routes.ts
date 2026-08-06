import { Router } from "express";
import { requireAuth, requireRole, AuthenticatedRequest } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  submitSparePartsSchema,
  sparePartsPaymentOrderSchema,
  verifySparePartsPaymentSchema,
  rejectSparePartsSchema
} from "./spare-parts.schemas.js";
import {
  submitSpareParts,
  createSparePartsPaymentOrder,
  verifySparePartsPayment,
  rejectSpareParts
} from "./spare-parts.service.js";

const router = Router();

// ── Worker: POST /bookings/:bookingId/spare-parts
// Worker submits itemized spare parts + optional receipt photo URL
router.post(
  "/bookings/:bookingId/spare-parts",
  requireAuth,
  requireRole("WORKER"),
  validate(submitSparePartsSchema),
  async (req: AuthenticatedRequest, res, next) => {
    try {
      const bookingId = req.params.bookingId as string;
      const { items, receiptPhotoUrl } = req.body;
      await submitSpareParts(req.auth!.userId, bookingId, items, receiptPhotoUrl);
      res.status(201).json({ success: true, message: "Spare parts request sent to customer" });
    } catch (err) {
      next(err);
    }
  }
);

// ── Customer: POST /bookings/:bookingId/spare-parts/payment-order
// Creates a Razorpay order for spare parts payment
router.post(
  "/bookings/:bookingId/spare-parts/payment-order",
  requireAuth,
  requireRole("CUSTOMER"),
  validate(sparePartsPaymentOrderSchema),
  async (req: AuthenticatedRequest, res, next) => {
    try {
      const bookingId = req.params.bookingId as string;
      const result = await createSparePartsPaymentOrder(req.auth!.userId, bookingId);
      res.json(result);
    } catch (err) {
      next(err);
    }
  }
);

// ── Customer: POST /bookings/:bookingId/spare-parts/verify-payment
// Verifies payment signature and marks spare parts as PAID
router.post(
  "/bookings/:bookingId/spare-parts/verify-payment",
  requireAuth,
  requireRole("CUSTOMER"),
  validate(verifySparePartsPaymentSchema),
  async (req: AuthenticatedRequest, res, next) => {
    try {
      const bookingId = req.params.bookingId as string;
      const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body;
      await verifySparePartsPayment(
        req.auth!.userId,
        bookingId,
        razorpayOrderId,
        razorpayPaymentId,
        razorpaySignature
      );
      res.json({ success: true, message: "Spare parts payment verified" });
    } catch (err) {
      next(err);
    }
  }
);

// ── Customer: POST /bookings/:bookingId/spare-parts/reject
// Customer rejects the spare parts request
router.post(
  "/bookings/:bookingId/spare-parts/reject",
  requireAuth,
  requireRole("CUSTOMER"),
  validate(rejectSparePartsSchema),
  async (req: AuthenticatedRequest, res, next) => {
    try {
      const bookingId = req.params.bookingId as string;
      await rejectSpareParts(req.auth!.userId, bookingId);
      res.json({ success: true, message: "Spare parts request rejected" });
    } catch (err) {
      next(err);
    }
  }
);

export { router as sparePartsRouter };
