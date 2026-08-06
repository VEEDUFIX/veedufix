import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  submitCustomQuoteSchema,
  acceptCustomQuoteSchema,
  rejectCustomQuoteSchema
} from "./custom-quote.schemas.js";
import {
  submitCustomQuote,
  acceptCustomQuote,
  rejectCustomQuote
} from "./custom-quote.service.js";
import type { AuthenticatedRequest } from "../../middleware/auth.js";
import type { Response } from "express";

export const customQuoteRouter = Router();

const workerOnly = [requireAuth, requireRole("WORKER")] as const;
const customerOnly = [requireAuth, requireRole("CUSTOMER")] as const;

// Worker submits a quote after visiting the site
customQuoteRouter.post(
  "/bookings/:bookingId/custom-quote",
  ...workerOnly,
  validate(submitCustomQuoteSchema),
  async (req: AuthenticatedRequest, res: Response) => {
    const bookingId = req.params.bookingId as string;
    const { items, notes } = req.body as { items: { label: string; amount: number }[]; notes?: string };
    await submitCustomQuote(req.auth!.userId, bookingId, items, notes);
    res.status(200).json({ message: "Quote sent to customer" });
  }
);

// Customer accepts the quote
customQuoteRouter.post(
  "/bookings/:bookingId/accept-quote",
  ...customerOnly,
  validate(acceptCustomQuoteSchema),
  async (req: AuthenticatedRequest, res: Response) => {
    const bookingId = req.params.bookingId as string;
    const result = await acceptCustomQuote(req.auth!.userId, bookingId);
    res.status(200).json({ message: "Quote accepted", ...result });
  }
);

// Customer rejects the quote
customQuoteRouter.post(
  "/bookings/:bookingId/reject-quote",
  ...customerOnly,
  validate(rejectCustomQuoteSchema),
  async (req: AuthenticatedRequest, res: Response) => {
    const bookingId = req.params.bookingId as string;
    await rejectCustomQuote(req.auth!.userId, bookingId);
    res.status(200).json({ message: "Quote rejected" });
  }
);
