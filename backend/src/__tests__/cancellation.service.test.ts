import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BookingStatus } from '@prisma/client';

const { updateMany, upsert } = vi.hoisted(() => ({
  updateMany: vi.fn(),
  upsert: vi.fn(),
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn((callback) => callback({
      booking: { updateMany },
      jobExecution: { upsert },
    })),
    booking: { findUnique: vi.fn(), updateMany },
    jobExecution: { upsert },
  },
}));
vi.mock('../lib/logger.js', () => ({ logger: { info: vi.fn() } }));
vi.mock('../lib/realtime.js', () => ({ publishNotificationEvent: vi.fn() }));
vi.mock('../lib/booking-timeline.js', () => ({ recordBookingTimelineEvent: vi.fn() }));

import { prisma } from '../lib/prisma.js';
import {
  cancelBooking,
  CancellationConflictError,
} from '../modules/matching/cancellation.service.js';

describe('cancelBooking state transitions', () => {
  beforeEach(() => vi.clearAllMocks());

  it('does not overwrite a booking that became terminal after it was read', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      id: 'booking-1',
      code: 'VF-1',
      customerId: 'customer-1',
      workerId: null,
      status: BookingStatus.PENDING,
      jobExecution: null,
      worker: null,
    } as never);
    vi.mocked(prisma.booking.updateMany).mockResolvedValue({ count: 0 });

    await expect(
      cancelBooking('booking-1', 'customer', 'customer-1', 'Changed plans'),
    ).rejects.toBeInstanceOf(CancellationConflictError);
    expect(prisma.jobExecution.upsert).not.toHaveBeenCalled();
  });

  it('cancels only while the booking remains in a cancellable state', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      id: 'booking-1',
      code: 'VF-1',
      customerId: 'customer-1',
      workerId: null,
      status: BookingStatus.PENDING,
      jobExecution: null,
      worker: null,
    } as never);
    vi.mocked(prisma.booking.updateMany).mockResolvedValue({ count: 1 });
    vi.mocked(prisma.jobExecution.upsert).mockResolvedValue({} as never);

    await expect(
      cancelBooking('booking-1', 'customer', 'customer-1', 'Changed plans'),
    ).resolves.toMatchObject({ status: BookingStatus.CANCELLED_MANUAL });
    expect(prisma.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({
        id: 'booking-1',
        status: expect.objectContaining({ notIn: expect.arrayContaining([BookingStatus.COMPLETED]) }),
      }),
    }));
  });
});
