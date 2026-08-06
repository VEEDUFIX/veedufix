import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { logger } from "../../lib/logger.js";
import { sendMulticastPush } from "../../lib/fcm.js";

// ── Types ────────────────────────────────────────────────────────────────────

export interface QuoteLineItem {
  label: string;
  amount: number;
}

// ── Worker: Submit custom quote after site visit ─────────────────────────────

export async function submitCustomQuote(
  workerId: string,
  bookingId: string,
  items: QuoteLineItem[],
  notes?: string
): Promise<void> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      worker: true,
      customer: { select: { id: true, name: true } }
    }
  });

  if (!booking) throw AppError.notFound("Booking not found");

  // Ensure this worker is assigned to the booking
  if (booking.worker?.userId !== workerId) {
    throw AppError.forbidden("You are not assigned to this booking");
  }

  // Only site-visit bookings can have a custom quote submitted
  if (booking.customQuoteStatus === "ACCEPTED") {
    throw AppError.conflict("A quote has already been accepted for this booking");
  }

  const totalAmount = items.reduce((sum, item) => sum + item.amount, 0);

  await prisma.booking.update({
    where: { id: bookingId },
    data: {
      customQuoteAmount: totalAmount,
      customQuoteItemized: items,
      customQuoteNotes: notes ?? null,
      customQuoteStatus: "PENDING"
    }
  });

  // Push notification to customer
  try {
    const deviceTokens = await prisma.deviceToken.findMany({
      where: { userId: booking.customerId },
      select: { token: true }
    });
    const tokens = deviceTokens.map((d) => d.token);
    if (tokens.length > 0) {
      await sendMulticastPush({
        tokens,
        title: "Quote Received! 📋",
        body: `Worker has submitted a custom quote of ₹${totalAmount.toFixed(2)} for your booking.`,
        data: { type: "CUSTOM_QUOTE_RECEIVED", bookingId }
      });
    }
  } catch (err) {
    logger.warn({ err, bookingId }, "submitCustomQuote: failed to send push notification");
  }

  logger.info({ bookingId, workerId, totalAmount }, "Custom quote submitted");
}

// ── Customer: Accept a custom quote ──────────────────────────────────────────

export async function acceptCustomQuote(
  customerId: string,
  bookingId: string
): Promise<{ quoteAmount: number }> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { worker: { include: { user: true } } }
  });

  if (!booking) throw AppError.notFound("Booking not found");
  if (booking.customerId !== customerId) throw AppError.forbidden("Access denied");
  if (booking.customQuoteStatus !== "PENDING") {
    throw AppError.conflict("No pending quote to accept");
  }
  if (!booking.customQuoteAmount) {
    throw AppError.conflict("Quote amount is missing");
  }

  const quoteAmount = Number(booking.customQuoteAmount);

  await prisma.booking.update({
    where: { id: bookingId },
    data: {
      customQuoteStatus: "ACCEPTED",
      totalAmount: quoteAmount
    }
  });

  // Notify worker
  try {
    if (booking.worker) {
      const deviceTokens = await prisma.deviceToken.findMany({
        where: { userId: booking.worker.userId },
        select: { token: true }
      });
      const tokens = deviceTokens.map((d) => d.token);
      if (tokens.length > 0) {
        await sendMulticastPush({
          tokens,
          title: "Quote Accepted! ✅",
          body: `Customer has accepted your custom quote of ₹${booking.customQuoteAmount?.toFixed(2) || '0.00'}.`,
          data: { type: "CUSTOM_QUOTE_ACCEPTED", bookingId }
        });
      }
    }
  } catch (err) {
    logger.warn({ err, bookingId }, "acceptCustomQuote: failed to send push notification");
  }

  logger.info({ bookingId, customerId, quoteAmount }, "Custom quote accepted");
  return { quoteAmount };
}

// ── Customer: Reject a custom quote ──────────────────────────────────────────

export async function rejectCustomQuote(
  customerId: string,
  bookingId: string
): Promise<void> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId }
  });

  if (!booking) throw AppError.notFound("Booking not found");
  if (booking.customerId !== customerId) throw AppError.forbidden("Access denied");
  if (booking.customQuoteStatus !== "PENDING") {
    throw AppError.conflict("No pending quote to reject");
  }

  await prisma.booking.update({
    where: { id: bookingId },
    data: { customQuoteStatus: "REJECTED" }
  });

  logger.info({ bookingId, customerId }, "Custom quote rejected");
}
