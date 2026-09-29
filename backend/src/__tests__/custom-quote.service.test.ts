import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: vi.fn() },
  },
}));

import { prisma } from '../lib/prisma.js';
import { getCustomQuote } from '../modules/bookings/custom-quote.service.js';

const booking = {
  id: 'booking-1',
  customerId: 'customer-user-1',
  workerId: 'worker-profile-1',
  worker: { userId: 'worker-user-1' },
  customQuoteStatus: 'SUBMITTED',
  customQuoteAmount: 2500,
  customQuoteNotes: null,
  customQuoteItemized: null,
};
const quote = {
  id: booking.id,
  customerId: booking.customerId,
  workerId: booking.workerId,
  customQuoteStatus: booking.customQuoteStatus,
  customQuoteAmount: booking.customQuoteAmount,
  customQuoteNotes: booking.customQuoteNotes,
  customQuoteItemized: booking.customQuoteItemized,
};

describe('getCustomQuote access', () => {
  beforeEach(() => vi.clearAllMocks());

  it('allows the owning customer', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(booking as never);

    await expect(getCustomQuote('booking-1', 'customer-user-1')).resolves.toEqual(quote);
  });

  it('allows the assigned worker by user ID, not profile ID', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(booking as never);

    await expect(getCustomQuote('booking-1', 'worker-user-1')).resolves.toEqual(quote);
  });

  it('rejects users unrelated to the booking', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(booking as never);

    await expect(getCustomQuote('booking-1', 'other-user')).rejects.toMatchObject({
      statusCode: 403,
    });
  });
});
