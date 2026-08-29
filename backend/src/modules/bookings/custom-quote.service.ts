import { UserRole } from "@prisma/client";
import { prisma } from '../../lib/prisma.js';
import { AppError } from '../../lib/app-error.js';

// Customer requests a custom quote for an existing booking
export async function requestCustomQuote(bookingId: string, customerId: string, notes?: string) {
  const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
  if (!booking) throw AppError.notFound('Booking not found');
  if (booking.customerId !== customerId) throw AppError.forbidden('Not your booking');
  if (booking.customQuoteStatus && booking.customQuoteStatus !== 'DECLINED') {
    throw AppError.conflict('A custom quote is already in progress for this booking');
  }
  return prisma.booking.update({
    where: { id: bookingId },
    data: { customQuoteStatus: 'REQUESTED', customQuoteNotes: notes ?? null }
  });
}

// Admin/worker submits a quote price
export async function submitCustomQuote(
  bookingId: string,
  submitterId: string,
  submitterRole: UserRole,
  amount: number,
  notes?: string,
  itemized?: Array<{ label: string; qty: number; unitPrice: number }>
) {
  const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
  if (!booking) throw AppError.notFound('Booking not found');
  if (booking.customQuoteStatus !== 'REQUESTED') {
    throw AppError.conflict('Booking does not have an active custom quote request');
  }

  if (submitterRole !== "ADMIN") {
    const workerProfile = await prisma.workerProfile.findUnique({
      where: { userId: submitterId },
      select: { id: true }
    });

    if (!workerProfile || booking.workerId !== workerProfile.id) {
      throw AppError.forbidden('Only the assigned worker can submit this quote');
    }
  }

  return prisma.booking.update({
    where: { id: bookingId },
    data: {
      customQuoteStatus: 'SUBMITTED',
      customQuoteAmount: amount,
      customQuoteNotes: notes ?? null,
      customQuoteItemized: itemized ?? null
    }
  });
}

// Customer accepts or declines a submitted quote
export async function respondToCustomQuote(bookingId: string, customerId: string, accept: boolean) {
  const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
  if (!booking) throw AppError.notFound('Booking not found');
  if (booking.customerId !== customerId) throw AppError.forbidden('Not your booking');
  if (booking.customQuoteStatus !== 'SUBMITTED') {
    throw AppError.conflict('No submitted quote to respond to');
  }
  const newStatus = accept ? 'ACCEPTED' : 'DECLINED';
  return prisma.booking.update({
    where: { id: bookingId },
    data: { customQuoteStatus: newStatus }
  });
}

// Get custom quote details for a booking
export async function getCustomQuote(bookingId: string, userId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      customerId: true,
      workerId: true,
      customQuoteStatus: true,
      customQuoteAmount: true,
      customQuoteNotes: true,
      customQuoteItemized: true
    }
  });
  if (!booking) throw AppError.notFound('Booking not found');
  if (booking.customerId !== userId && booking.workerId !== userId) {
    throw AppError.forbidden('Access denied');
  }
  return booking;
}
