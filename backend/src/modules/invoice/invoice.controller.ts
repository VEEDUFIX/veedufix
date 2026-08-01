import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import { generateInvoiceForBooking, getInvoiceForBooking } from "./invoice.service.js";
import { prisma } from "../../lib/prisma.js";

export async function getBookingInvoiceHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  const bookingId = String(request.params.bookingId);
  const userId = request.auth?.userId;
  const role = request.auth?.role;

  if (!userId) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      customerId: true
    }
  });

  if (!booking) {
    response.status(404).json({ message: "Booking not found" });
    return;
  }

  if (role !== "ADMIN" && booking.customerId !== userId) {
    response.status(403).json({ message: "Access denied" });
    return;
  }

  try {
    const existingInvoice = await getInvoiceForBooking(bookingId);
    const invoice = existingInvoice ?? (await generateInvoiceForBooking(bookingId));

    response.status(200).json({ invoice });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to load invoice";
    response.status(400).json({ message });
  }
}
