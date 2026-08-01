import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { getBookingInvoiceHandler } from "./invoice.controller.js";

export const invoiceRouter = Router();

invoiceRouter.get("/bookings/:bookingId/invoice", requireAuth, getBookingInvoiceHandler);
