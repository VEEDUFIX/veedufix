import { beforeEach, describe, expect, it, vi } from 'vitest';

const { payoutFindMany, payoutFindUnique, payoutUpdateMany, commissionFindFirst, platformConfigFindUnique } = vi.hoisted(() => ({
  payoutFindMany: vi.fn(),
  payoutFindUnique: vi.fn(),
  payoutUpdateMany: vi.fn(),
  platformConfigFindUnique: vi.fn(),
  commissionFindFirst: vi.fn()
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    payout: { findMany: payoutFindMany, findUnique: payoutFindUnique, updateMany: payoutUpdateMany },
    platformConfig: { findUnique: platformConfigFindUnique },
    commissions: { findFirst: commissionFindFirst }
  },
}));
vi.mock('../config/env.js', () => ({ env: {} }));

import {
  calculatePayoutAmounts,
  exportPayoutsCsv,
  getCommissionForCity,
  releasePendingPayouts,
  bulkRetryFailedPayouts
} from '../modules/payout/payout.service.js';
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

describe('admin commission rules applied to payouts', () => {
  beforeEach(() => vi.clearAllMocks());

  it('prefers an active city-specific rule', async () => {
    vi.mocked(prisma.commissions.findFirst).mockResolvedValueOnce({
      rate: 12.5,
      fixedFee: 5
    } as never);

    await expect(getCommissionForCity('city-1')).resolves.toEqual({
      rate: 12.5,
      fixedFee: 5
    });
    expect(prisma.commissions.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: { cityId: 'city-1', isActive: true }
    }));
  });

  it('falls back to the active global rule when the city has no override', async () => {
    vi.mocked(prisma.commissions.findFirst)
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ rate: 18, fixedFee: 2 } as never);

    await expect(getCommissionForCity('city-1')).resolves.toEqual({
      rate: 18,
      fixedFee: 2
    });
    expect(prisma.commissions.findFirst).toHaveBeenNthCalledWith(2, expect.objectContaining({
      where: { cityId: null, isActive: true }
    }));
  });

  it('calculates the stored worker amount from the rule once', () => {
    expect(calculatePayoutAmounts(1000, { rate: 12.5, fixedFee: 5 })).toEqual({
      commissionAmount: 130,
      amount: 870
    });
  });
});

describe('platform payout pause control', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue({ payoutsPaused: true } as never);
  });

  it('does not release pending payouts while paused', async () => {
    await expect(releasePendingPayouts()).resolves.toEqual({
      attempted: 0,
      succeeded: 0,
      failed: 0,
      paused: true
    });
    expect(prisma.payout.findMany).not.toHaveBeenCalled();
  });

  it('blocks admin retries while payouts are paused', async () => {
    await expect(bulkRetryFailedPayouts()).rejects.toMatchObject({ statusCode: 400 });
    expect(prisma.payout.findMany).not.toHaveBeenCalled();
  });
});
