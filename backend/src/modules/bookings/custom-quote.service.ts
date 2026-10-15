import { BookingStatus, UserRole } from "@prisma/client";
import { prisma } from '../../lib/prisma.js';
import { AppError } from '../../lib/app-error.js';

const QUOTE_TTL_MS = 48 * 60 * 60 * 1000;
export const terminalBookingStatuses: BookingStatus[] = [
  BookingStatus.COMPLETED,
  BookingStatus.CANCELLED,
  BookingStatus.CANCELLED_MANUAL,
  BookingStatus.CANCELLED_NO_SHOW,
  BookingStatus.REFUNDED
];
const activeQuoteBookingStatuses: BookingStatus[] = [
  BookingStatus.WORKER_ASSIGNED,
  BookingStatus.EN_ROUTE,
  BookingStatus.ARRIVED,
  BookingStatus.IN_PROGRESS
];

function money(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

async function latestRevision(bookingId: string) {
  return prisma.customQuoteRevision.findFirst({
    where: { bookingId },
    orderBy: { version: 'desc' }
  });
}

export async function requestCustomQuote(bookingId: string, customerId: string, notes?: string) {
  const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
  if (!booking) throw AppError.notFound('Booking not found');
  if (booking.customerId !== customerId) throw AppError.forbidden('Not your booking');
  if (terminalBookingStatuses.includes(booking.status)) {
    throw AppError.conflict('A quote cannot be requested for a closed booking');
  }
  if (!booking.workerId || !activeQuoteBookingStatuses.includes(booking.status)) {
    throw AppError.conflict('A quote can be requested only after a Partner is assigned and the job is active');
  }
  if (booking.customQuoteStatus && !['DECLINED', 'REJECTED', 'EXPIRED'].includes(booking.customQuoteStatus)) {
    throw AppError.conflict('A custom quote is already in progress for this booking');
  }

  return prisma.$transaction(async (tx) => {
    const claimed = await tx.booking.updateMany({
      where: {
        id: bookingId,
        workerId: booking.workerId,
        status: { in: activeQuoteBookingStatuses },
        customQuoteRevision: booking.customQuoteRevision,
        customQuoteStatus: booking.customQuoteStatus
      },
      data: {
        customQuoteRevision: { increment: 1 },
        customQuoteStatus: 'REQUESTED',
        customQuoteAmount: null,
        customQuoteItemized: null,
        customQuoteNotes: notes ?? null
      }
    });
    if (claimed.count !== 1) throw AppError.conflict('The quote changed. Refresh and try again.');
    await tx.customQuoteRevision.create({
      data: {
        bookingId,
        version: booking.customQuoteRevision + 1,
        status: 'REQUESTED',
        requestNotes: notes ?? null,
        requestedBy: customerId
      }
    });
    return tx.booking.findUniqueOrThrow({ where: { id: bookingId } });
  });
}

export async function submitCustomQuote(
  bookingId: string,
  submitterId: string,
  submitterRole: UserRole,
  amount: number,
  notes?: string,
  itemized?: Array<{ label: string; qty: number; unitPrice: number }>
) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { services: { select: { gstRate: true } } }
  });
  if (!booking) throw AppError.notFound('Booking not found');
  if (booking.customQuoteStatus !== 'REQUESTED') {
    throw AppError.conflict('Booking does not have an active custom quote request');
  }
  if (terminalBookingStatuses.includes(booking.status)) {
    throw AppError.conflict('A quote cannot be submitted for a closed booking');
  }

  if (submitterRole !== UserRole.ADMIN) {
    const workerProfile = await prisma.workerProfile.findUnique({
      where: { userId: submitterId },
      select: { id: true }
    });
    if (!workerProfile || booking.workerId !== workerProfile.id) {
      throw AppError.forbidden('Only the assigned Partner can submit this quote');
    }
  }

  if (!itemized?.length) throw AppError.badRequest('Add at least one itemized charge');
  const itemTotal = money(itemized.reduce((sum, item) => sum + item.qty * item.unitPrice, 0));
  if (money(amount) !== itemTotal) throw AppError.badRequest('Quote amount must equal the itemized charges');
  if (!Number.isFinite(amount) || amount <= 0) throw AppError.badRequest('Quote amount must be greater than zero');

  const submittedAt = new Date();
  const expiresAt = new Date(submittedAt.getTime() + QUOTE_TTL_MS);
  const gstRate = Number(booking.services[0]?.gstRate ?? 0);
  const taxAmount = gstRate > 0 ? money(amount - amount / (1 + gstRate / 100)) : 0;
  const revision = await latestRevision(bookingId);
  if (!revision || revision.status !== 'REQUESTED') {
    throw AppError.conflict('The quote request is no longer active');
  }

  return prisma.$transaction(async (tx) => {
    const claim = await tx.booking.updateMany({
      where: {
        id: bookingId,
        workerId: booking.workerId,
        status: { in: activeQuoteBookingStatuses },
        customQuoteRevision: revision.version,
        customQuoteStatus: 'REQUESTED'
      },
      data: {
        customQuoteStatus: 'SUBMITTED',
        customQuoteAmount: money(amount),
        customQuoteNotes: notes ?? null,
        customQuoteItemized: itemized
      }
    });
    const revisionUpdate = claim.count === 1
      ? await tx.customQuoteRevision.updateMany({
          where: { id: revision.id, status: 'REQUESTED' },
          data: {
            status: 'SUBMITTED',
            submittedBy: submitterId,
            submittedAt,
            expiresAt,
            amount: money(amount),
            taxAmount,
            itemized,
            notes: notes ?? null
          }
        })
      : { count: 0 };
    if (claim.count !== 1 || revisionUpdate.count !== 1) {
      throw AppError.conflict('The quote request changed. Refresh and try again.');
    }
    return tx.booking.findUniqueOrThrow({ where: { id: bookingId } });
  });
}

export async function respondToCustomQuote(bookingId: string, customerId: string, accept: boolean) {
  const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
  if (!booking) throw AppError.notFound('Booking not found');
  if (booking.customerId !== customerId) throw AppError.forbidden('Not your booking');
  if (booking.customQuoteStatus !== 'SUBMITTED') throw AppError.conflict('No submitted quote to respond to');
  if (terminalBookingStatuses.includes(booking.status)) {
    throw AppError.conflict('A quote cannot be answered for a closed booking');
  }
  const revision = await latestRevision(bookingId);
  if (!revision || revision.status !== 'SUBMITTED') throw AppError.conflict('No submitted quote to respond to');
  const now = new Date();
  if (revision.expiresAt && revision.expiresAt <= now) {
    await prisma.$transaction(async (tx) => {
      await tx.customQuoteRevision.updateMany({ where: { id: revision.id, status: 'SUBMITTED' }, data: { status: 'EXPIRED' } });
      await tx.booking.updateMany({ where: { id: bookingId, customQuoteRevision: revision.version, customQuoteStatus: 'SUBMITTED' }, data: { customQuoteStatus: 'EXPIRED' } });
    });
    throw AppError.conflict('This quote has expired. Request a revised quote.');
  }
  return prisma.$transaction(async (tx) => {
    const bookingClaim = await tx.booking.updateMany({
      where: {
        id: bookingId,
        customQuoteRevision: revision.version,
        customQuoteStatus: 'SUBMITTED',
        status: { notIn: terminalBookingStatuses }
      },
      data: { customQuoteStatus: accept ? 'ACCEPTED' : 'DECLINED' }
    });
    const revisionClaim = bookingClaim.count === 1
      ? await tx.customQuoteRevision.updateMany({
          where: { id: revision.id, status: 'SUBMITTED', ...(revision.expiresAt ? { expiresAt: { gt: now } } : {}) },
          data: {
            status: accept ? 'ACCEPTED' : 'DECLINED',
            respondedBy: customerId,
            respondedAt: now,
            paymentStatus: accept ? 'PENDING' : 'NOT_REQUIRED'
          }
        })
      : { count: 0 };
    if (bookingClaim.count !== 1 || revisionClaim.count !== 1) {
      throw AppError.conflict('This quote has already been answered or has expired');
    }
    return tx.booking.findUniqueOrThrow({ where: { id: bookingId } });
  });
}

export async function getCustomQuote(bookingId: string, userId: string, role?: UserRole) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      worker: { select: { userId: true } },
      customQuoteRevisions: { orderBy: { version: 'desc' }, include: { payments: { select: { id: true, status: true, amount: true, createdAt: true } } } }
    }
  });
  if (!booking) throw AppError.notFound('Booking not found');
  if (role !== UserRole.ADMIN && booking.customerId !== userId && booking.worker?.userId !== userId) {
    throw AppError.forbidden('Access denied');
  }
  return {
    id: booking.id,
    customerId: booking.customerId,
    workerId: booking.workerId,
    customQuoteStatus: booking.customQuoteStatus === 'REJECTED' ? 'DECLINED' : booking.customQuoteStatus,
    customQuoteAmount: booking.customQuoteAmount,
    customQuoteNotes: booking.customQuoteNotes,
    customQuoteItemized: booking.customQuoteItemized,
    history: booking.customQuoteRevisions
  };
}
export async function assertAdditionalWorkApproved(bookingId: string): Promise<void> {
  let quote = await prisma.customQuoteRevision.findFirst({
    where: { bookingId },
    orderBy: { version: 'desc' },
    select: { id: true, version: true, status: true, paymentStatus: true, expiresAt: true }
  });
  if (quote?.status === 'SUBMITTED' && quote.expiresAt && quote.expiresAt <= new Date()) {
    const expired = await prisma.$transaction(async (tx) => {
      const result = await tx.customQuoteRevision.updateMany({
        where: { id: quote!.id, status: 'SUBMITTED', expiresAt: { lte: new Date() } },
        data: { status: 'EXPIRED' }
      });
      if (result.count === 1) {
        await tx.booking.updateMany({
          where: { id: bookingId, customQuoteRevision: quote!.version, customQuoteStatus: 'SUBMITTED' },
          data: { customQuoteStatus: 'EXPIRED' }
        });
      }
      return result.count === 1;
    });
    if (expired) {
      quote = { ...quote, status: 'EXPIRED' };
    } else {
      quote = await prisma.customQuoteRevision.findFirst({
        where: { bookingId },
        orderBy: { version: 'desc' },
        select: { id: true, version: true, status: true, paymentStatus: true, expiresAt: true }
      });
    }
  }
  if (quote && (quote.status === 'SUBMITTED' || (quote.status === 'ACCEPTED' && !['PAID', 'LEGACY_UNVERIFIED'].includes(quote.paymentStatus)))) {
    throw AppError.conflict('Additional quoted work cannot continue until the customer approves and pays the quote');
  }
}
