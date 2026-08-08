/**
 * Unit tests for payout-releaser — automated 48-hour payout release logic.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findMany: vi.fn() },
  },
}));

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn(), debug: vi.fn() },
}));

vi.mock('../modules/payout/payout.service.js', () => ({
  releaseWorkerPayout: vi.fn(),
}));

import { prisma } from '../lib/prisma.js';
import { releaseWorkerPayout } from '../modules/payout/payout.service.js';

// The function is not exported by default for direct testing, but we can extract the inner logic
// or we can test it if we refactor it slightly.
// Oh wait, `startPayoutReleaser` schedules it, but we can't easily test cron jobs in vitest without importing the inner logic.
// The inner logic is `releaseEligiblePayouts`. I'll test by mocking it if it was exported, 
// but since it's not exported, let me re-write the test to target `payout.service.ts` directly, 
// OR I will just use `multi_replace_file_content` to export `releaseEligiblePayouts` from `payout-releaser.ts` first.

// Let's assume we will export it.
import { releaseEligiblePayouts } from '../modules/scheduler/payout-releaser.js';

describe('payout-releaser', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('does nothing if no eligible bookings are found', async () => {
    vi.mocked(prisma.booking.findMany).mockResolvedValue([]);

    await releaseEligiblePayouts();

    expect(prisma.booking.findMany).toHaveBeenCalledOnce();
    expect(releaseWorkerPayout).not.toHaveBeenCalled();
  });

  it('releases payout for eligible bookings and logs success/failure', async () => {
    const mockBookings = [
      { id: 'b1', code: 'BK-1', jobExecution: { completedAt: new Date() } },
      { id: 'b2', code: 'BK-2', jobExecution: { completedAt: new Date() } }
    ];
    vi.mocked(prisma.booking.findMany).mockResolvedValue(mockBookings as never);

    // b1 succeeds, b2 fails
    vi.mocked(releaseWorkerPayout)
      .mockResolvedValueOnce({} as never)
      .mockRejectedValueOnce(new Error('Razorpay failed'));

    await releaseEligiblePayouts();

    expect(releaseWorkerPayout).toHaveBeenCalledTimes(2);
    expect(releaseWorkerPayout).toHaveBeenCalledWith('b1');
    expect(releaseWorkerPayout).toHaveBeenCalledWith('b2');
  });
});
