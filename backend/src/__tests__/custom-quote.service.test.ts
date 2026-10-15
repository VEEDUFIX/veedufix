import { beforeEach, describe, expect, it, vi } from 'vitest';

const tx = {
  booking: { updateMany: vi.fn(), findUniqueOrThrow: vi.fn() },
  customQuoteRevision: { create: vi.fn(), updateMany: vi.fn() }
};

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: vi.fn() },
    workerProfile: { findUnique: vi.fn() },
    customQuoteRevision: { findFirst: vi.fn() },
    $transaction: vi.fn(async (callback: (client: typeof tx) => unknown) => callback(tx))
  }
}));

import { prisma } from '../lib/prisma.js';
import { assertAdditionalWorkApproved, getCustomQuote, requestCustomQuote, respondToCustomQuote, submitCustomQuote } from '../modules/bookings/custom-quote.service.js';
import { respondCustomQuoteSchema } from '../modules/bookings/custom-quote.schemas.js';

const booking = {
  id: 'booking-1', customerId: 'customer-user-1', workerId: 'worker-profile-1',
  worker: { userId: 'worker-user-1' }, status: 'IN_PROGRESS', customQuoteRevision: 1,
  customQuoteStatus: 'SUBMITTED', customQuoteAmount: 2500, customQuoteNotes: 'labor',
  customQuoteItemized: [{ label: 'Labor', qty: 1, unitPrice: 2500 }], services: [{ gstRate: 18 }]
} as never;
const quoteRevision = {
  id: 'revision-1', bookingId: 'booking-1', version: 1, status: 'SUBMITTED',
  expiresAt: new Date(Date.now() + 60_000), amount: 2500, taxAmount: 381.36,
  itemized: [{ label: 'Labor', qty: 1, unitPrice: 2500 }], paymentStatus: 'NOT_REQUIRED'
};

function prepareTransaction() {
  tx.booking.updateMany.mockResolvedValue({ count: 1 });
  tx.booking.findUniqueOrThrow.mockResolvedValue(booking);
  tx.customQuoteRevision.create.mockResolvedValue({ id: 'revision-2' });
  tx.customQuoteRevision.updateMany.mockResolvedValue({ count: 1 });
}

describe('custom quote lifecycle', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    prepareTransaction();
  });

  it('accepts only the backend {accept:boolean} response contract', () => {
    expect(respondCustomQuoteSchema.parse({
      body: { accept: true }, params: { bookingId: 'booking-1' }, query: {}
    }).body.accept).toBe(true);
    expect(() => respondCustomQuoteSchema.parse({
      body: { action: 'accept' }, params: { bookingId: 'booking-1' }, query: {}
    })).toThrow();
  });

  it('customer approval atomically changes SUBMITTED to ACCEPTED and awaits payment', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(booking as never);
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue(quoteRevision as never);
    await respondToCustomQuote('booking-1', 'customer-user-1', true);
    expect(tx.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ customQuoteStatus: 'SUBMITTED' }),
      data: { customQuoteStatus: 'ACCEPTED' }
    }));
    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ status: 'ACCEPTED', paymentStatus: 'PENDING', respondedBy: 'customer-user-1' })
    }));
  });

  it('customer rejection uses canonical DECLINED status', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(booking as never);
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue(quoteRevision as never);
    await respondToCustomQuote('booking-1', 'customer-user-1', false);
    expect(tx.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { customQuoteStatus: 'DECLINED' } }));
    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ status: 'DECLINED', paymentStatus: 'NOT_REQUIRED' })
    }));
  });

  it('rejects an unrelated customer before attempting a transition', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(booking as never);
    await expect(respondToCustomQuote('booking-1', 'other-user', true)).rejects.toMatchObject({ statusCode: 403 });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a quote response after the booking has closed', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({ ...booking, status: 'CANCELLED_MANUAL' } as never);
    await expect(respondToCustomQuote('booking-1', 'customer-user-1', true))
      .rejects.toMatchObject({ statusCode: 409 });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('allows only one concurrent response to claim the quote', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(booking as never);
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue(quoteRevision as never);
    tx.booking.updateMany.mockResolvedValueOnce({ count: 0 });
    await expect(respondToCustomQuote('booking-1', 'customer-user-1', true)).rejects.toMatchObject({ statusCode: 409 });
    expect(tx.customQuoteRevision.updateMany).not.toHaveBeenCalled();
  });

  it('expires a submitted quote rather than accepting an expired amount', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(booking as never);
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({ ...quoteRevision, expiresAt: new Date(Date.now() - 1) } as never);
    await expect(respondToCustomQuote('booking-1', 'customer-user-1', true)).rejects.toMatchObject({ statusCode: 409 });
    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'EXPIRED' } }));
    expect(tx.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { customQuoteStatus: 'EXPIRED' } }));
  });

  it('starts a new numbered revision after a declined quote', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({ ...booking, customQuoteStatus: 'DECLINED' } as never);
    await requestCustomQuote('booking-1', 'customer-user-1', 'Please revise');
    expect(tx.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ customQuoteRevision: 1, customQuoteStatus: 'DECLINED' }),
      data: expect.objectContaining({ customQuoteRevision: { increment: 1 }, customQuoteStatus: 'REQUESTED' })
    }));
    expect(tx.customQuoteRevision.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ version: 2, status: 'REQUESTED', requestedBy: 'customer-user-1' })
    }));
  });

  it('rejects an unassigned Partner attempting to submit', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({ ...booking, customQuoteStatus: 'REQUESTED' } as never);
    vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue({ id: 'different-profile' } as never);
    await expect(submitCustomQuote('booking-1', 'worker-user-1', 'WORKER' as never, 100, undefined, [
      { label: 'Labor', qty: 1, unitPrice: 100 }
    ])).rejects.toMatchObject({ statusCode: 403 });
  });

  it('rejects totals that do not match itemized charges', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({ ...booking, customQuoteStatus: 'REQUESTED' } as never);
    vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue({ id: 'worker-profile-1' } as never);
    await expect(submitCustomQuote('booking-1', 'worker-user-1', 'WORKER' as never, 2500, undefined, [
      { label: 'Labor', qty: 1, unitPrice: 2000 }
    ])).rejects.toMatchObject({ statusCode: 400 });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('returns quote history to the booking owner and assigned Partner, and blocks unrelated users', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({ ...booking, customQuoteRevisions: [quoteRevision] } as never);
    await expect(getCustomQuote('booking-1', 'customer-user-1')).resolves.toMatchObject({ history: [quoteRevision] });
    await expect(getCustomQuote('booking-1', 'worker-user-1')).resolves.toMatchObject({ history: [quoteRevision] });
    await expect(getCustomQuote('booking-1', 'other-user')).rejects.toMatchObject({ statusCode: 403 });
  });
});
describe('additional work approval gate', () => {
  beforeEach(() => vi.clearAllMocks());

  it('blocks work while the customer has not responded', async () => {
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({ status: 'SUBMITTED', paymentStatus: 'NOT_REQUIRED' } as never);
    await expect(assertAdditionalWorkApproved('booking-1')).rejects.toMatchObject({ statusCode: 409 });
  });

  it('blocks approved quoted work until payment is captured', async () => {
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({ status: 'ACCEPTED', paymentStatus: 'PAYMENT_PENDING' } as never);
    await expect(assertAdditionalWorkApproved('booking-1')).rejects.toMatchObject({ statusCode: 409 });
  });

  it('expires an unanswered quote and lets the original job continue', async () => {
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({
      id: 'revision-1', version: 1, status: 'SUBMITTED', paymentStatus: 'NOT_REQUIRED',
      expiresAt: new Date(Date.now() - 1)
    } as never);
    tx.customQuoteRevision.updateMany.mockResolvedValue({ count: 1 });
    tx.booking.updateMany.mockResolvedValue({ count: 1 });

    await expect(assertAdditionalWorkApproved('booking-1')).resolves.toBeUndefined();

    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ id: 'revision-1', status: 'SUBMITTED' }),
      data: { status: 'EXPIRED' }
    }));
    expect(tx.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ customQuoteRevision: 1, customQuoteStatus: 'SUBMITTED' }),
      data: { customQuoteStatus: 'EXPIRED' }
    }));
  });

  it('rechecks the latest quote when expiration loses a concurrent transition', async () => {
    vi.mocked(prisma.customQuoteRevision.findFirst)
      .mockResolvedValueOnce({
        id: 'revision-1', version: 1, status: 'SUBMITTED', paymentStatus: 'NOT_REQUIRED',
        expiresAt: new Date(Date.now() - 1)
      } as never)
      .mockResolvedValueOnce({
        id: 'revision-1', version: 1, status: 'ACCEPTED', paymentStatus: 'PAYMENT_PENDING', expiresAt: null
      } as never);
    tx.customQuoteRevision.updateMany.mockResolvedValue({ count: 0 });

    await expect(assertAdditionalWorkApproved('booking-1')).rejects.toMatchObject({ statusCode: 409 });
  });
  it('allows work after explicit rejection or verified payment', async () => {
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({ status: 'DECLINED', paymentStatus: 'NOT_REQUIRED' } as never);
    await expect(assertAdditionalWorkApproved('booking-1')).resolves.toBeUndefined();
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({ status: 'ACCEPTED', paymentStatus: 'PAID' } as never);
    await expect(assertAdditionalWorkApproved('booking-1')).resolves.toBeUndefined();
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({ status: 'ACCEPTED', paymentStatus: 'LEGACY_UNVERIFIED' } as never);
    await expect(assertAdditionalWorkApproved('booking-1')).resolves.toBeUndefined();
  });
});
