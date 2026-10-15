import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BookingStatus } from '@prisma/client';

const { updateMany, upsert, releaseOccurrence, planEventCreate } = vi.hoisted(() => ({
  updateMany: vi.fn(),
  upsert: vi.fn(),
  releaseOccurrence: vi.fn(),
  planEventCreate: vi.fn()
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn((callback) => callback({
      booking: { updateMany },
      jobExecution: { upsert },
      maintenanceOccurrence: { findMany: vi.fn().mockResolvedValue([{ id: "occurrence-1", planId: "plan-1", dueAt: new Date("2026-10-12T00:00:00.000Z"), sequence: 1, plan: { status: "ACTIVE" } }]), updateMany: releaseOccurrence },
      maintenancePlanEvent: { create: planEventCreate },
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
  beforeEach(() => {
    vi.clearAllMocks();
    releaseOccurrence.mockResolvedValue({ count: 1 });
  });

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
    expect(releaseOccurrence).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: "occurrence-1", bookingId: "booking-1", status: "BOOKING_CREATED" },
      data: expect.objectContaining({ bookingId: null, status: "AWAITING_CONFIRMATION" })
    }));
    expect(planEventCreate).toHaveBeenCalledWith({
      data: {
        planId: "plan-1",
        action: "LINKED_BOOKING_CANCELLED",
        details: expect.objectContaining({ occurrenceId: "occurrence-1", bookingId: "booking-1", sequence: 1 })
      }
    });
    expect(prisma.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({
        id: 'booking-1',
        customerId: 'customer-1',
        status: expect.objectContaining({ notIn: expect.arrayContaining([BookingStatus.COMPLETED]) }),
      }),
    }));
  });

  it('returns the existing cancellation for a repeated authorized request', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      id: 'booking-1',
      code: 'VF-1',
      customerId: 'customer-1',
      workerId: null,
      status: BookingStatus.CANCELLED_MANUAL,
      jobExecution: { status: 'cancelled' },
      worker: null,
    } as never);

    await expect(
      cancelBooking('booking-1', 'customer', 'customer-1', 'Retry'),
    ).resolves.toMatchObject({ status: BookingStatus.CANCELLED_MANUAL });
    expect(prisma.booking.updateMany).not.toHaveBeenCalled();
    expect(prisma.jobExecution.upsert).not.toHaveBeenCalled();
  });

  it('does not report a no-show booking as cancelled by this request', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      id: 'booking-1',
      code: 'VF-1',
      customerId: 'customer-1',
      workerId: null,
      status: BookingStatus.CANCELLED_NO_SHOW,
      jobExecution: { status: 'cancelled' },
      worker: null,
    } as never);
    vi.mocked(prisma.booking.updateMany).mockResolvedValue({ count: 0 });

    await expect(
      cancelBooking('booking-1', 'customer', 'customer-1', 'Retry'),
    ).rejects.toBeInstanceOf(CancellationConflictError);
    expect(prisma.jobExecution.upsert).not.toHaveBeenCalled();
  });

  it('does not cancel a terminal job execution even if its booking status is stale', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      id: 'booking-1',
      code: 'VF-1',
      customerId: 'customer-1',
      workerId: null,
      status: BookingStatus.IN_PROGRESS,
      jobExecution: { status: 'completed' },
      worker: null,
    } as never);

    await expect(
      cancelBooking('booking-1', 'customer', 'customer-1', 'Too late'),
    ).rejects.toBeInstanceOf(CancellationConflictError);
    expect(prisma.booking.updateMany).not.toHaveBeenCalled();
  });
});
