import { beforeEach, describe, expect, it, vi } from 'vitest';

const { payoutFindMany } = vi.hoisted(() => ({ payoutFindMany: vi.fn() }));

vi.mock('../lib/prisma.js', () => ({
  prisma: { payout: { findMany: payoutFindMany } },
}));
vi.mock('../config/env.js', () => ({ env: {} }));

import { exportPayoutsCsv } from '../modules/payout/payout.service.js';
import { prisma } from '../lib/prisma.js';

describe('payout CSV export', () => {
  beforeEach(() => vi.clearAllMocks());

  it('exports payout amounts in rupees, matching the admin ledger and partner earnings APIs', async () => {
    vi.mocked(prisma.payout.findMany).mockResolvedValue([{
      id: 'payout-1',
      bookingId: 'booking-1',
      workerId: 'worker-1',
      amount: 80,
      commissionAmount: 20,
      status: 'pending',
      failureReason: null,
      createdAt: new Date('2026-09-29T10:00:00.000Z'),
      booking: {
        code: 'VF-1001',
        worker: { fullName: 'Partner Name', user: { name: 'Partner Name' } },
      },
    }] as never);

    const csv = await exportPayoutsCsv();

    expect(csv).toContain('payout-1,VF-1001,Partner Name,80.00,pending');
  });
});
