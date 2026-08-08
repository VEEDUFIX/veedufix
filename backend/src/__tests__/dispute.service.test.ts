/**
 * Unit tests for dispute.service — 48-hour dispute grace period logic.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: vi.fn(), findMany: vi.fn() },
    dispute: { create: vi.fn(), findFirst: vi.fn(), findUnique: vi.fn(), findMany: vi.fn(), count: vi.fn(), update: vi.fn() },
    refund: { update: vi.fn() },
    user: { findMany: vi.fn() }
  },
}));

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn(), debug: vi.fn() },
}));

vi.mock('../lib/realtime.js', () => ({
  publishNotificationEvent: vi.fn(),
}));

vi.mock('../modules/refund/refund.service.js', () => ({
  processRefund: vi.fn(),
}));

import { prisma } from '../lib/prisma.js';
import { publishNotificationEvent } from '../lib/realtime.js';
import { processRefund } from '../modules/refund/refund.service.js';
import {
  raiseDispute,
  resolveDispute,
  BookingNotFoundError,
  DisputeAccessError,
  DisputeWindowExpiredError,
  DisputeConflictError
} from '../modules/dispute/dispute.service.js';

// ─── Test Data ────────────────────────────────────────────────────────────────

const MOCK_BOOKING_ID = 'book-123';
const MOCK_CUSTOMER_ID = 'cust-123';
const MOCK_DISPUTE_ID = 'disp-123';

const mockBookingEvidence = (completedAt: Date) => ({
  id: MOCK_BOOKING_ID,
  code: 'BK-0001',
  customerId: MOCK_CUSTOMER_ID,
  cityId: 'city-1',
  totalAmount: 1500,
  customerNotes: null,
  city: { id: 'city-1', name: 'Chennai', slug: 'chennai' },
  worker: { id: 'work-1', fullName: 'John Doe', displayName: 'John', user: { name: 'John Doe', avatarUrl: null } },
  jobExecution: {
    status: 'completed',
    beforePhotos: [],
    afterPhotos: [],
    checklist: {},
    completedAt
  }
});

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('dispute.service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('raiseDispute', () => {
    it('throws BookingNotFoundError if booking does not exist', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(null);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Bad service')).rejects.toThrow(BookingNotFoundError);
    });

    it('throws DisputeAccessError if the customer did not make the booking', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBookingEvidence(new Date()),
        customerId: 'different-cust'
      } as never);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Bad service')).rejects.toThrow(DisputeAccessError);
    });

    it('throws DisputeWindowExpiredError if the booking is older than 48 hours', async () => {
      const now = new Date('2026-08-01T12:00:00Z');
      vi.setSystemTime(now);

      // Completed 49 hours ago
      const completedAt = new Date(now.getTime() - 49 * 60 * 60 * 1000);

      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBookingEvidence(completedAt) as never);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Bad service')).rejects.toThrow(DisputeWindowExpiredError);
    });

    it('throws DisputeConflictError if an open dispute already exists', async () => {
      const now = new Date('2026-08-01T12:00:00Z');
      vi.setSystemTime(now);

      // Completed 10 hours ago (within 48h window)
      const completedAt = new Date(now.getTime() - 10 * 60 * 60 * 1000);

      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBookingEvidence(completedAt) as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue({ id: 'existing-dispute' } as never);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Bad service')).rejects.toThrow(DisputeConflictError);
    });

    it('creates a dispute and notifies admins when successfully raised within 48h window', async () => {
      const now = new Date('2026-08-01T12:00:00Z');
      vi.setSystemTime(now);

      // Completed 10 hours ago (within 48h window)
      const completedAt = new Date(now.getTime() - 10 * 60 * 60 * 1000);

      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBookingEvidence(completedAt) as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue(null);
      
      const mockDispute = { id: MOCK_DISPUTE_ID, bookingId: MOCK_BOOKING_ID, status: 'open', reason: 'Poor work' };
      vi.mocked(prisma.dispute.create).mockResolvedValue(mockDispute as never);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin-1' }] as never);

      const result = await raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor work');

      expect(result.id).toBe(MOCK_DISPUTE_ID);
      expect(prisma.dispute.create).toHaveBeenCalledWith({
        data: { bookingId: MOCK_BOOKING_ID, raisedBy: MOCK_CUSTOMER_ID, reason: 'Poor work', status: 'open' }
      });
      expect(publishNotificationEvent).toHaveBeenCalledOnce();
    });
  });

  describe('resolveDispute', () => {
    it('processes refund and updates dispute when resolution is refund', async () => {
      const mockDispute = {
        id: MOCK_DISPUTE_ID,
        status: 'open',
        bookingId: MOCK_BOOKING_ID,
        booking: { totalAmount: 1500 }
      };

      vi.mocked(prisma.dispute.findUnique).mockResolvedValue(mockDispute as never);
      vi.mocked(processRefund).mockResolvedValue({ id: 'ref-1' } as never);
      vi.mocked(prisma.refund.update).mockResolvedValue({} as never);
      vi.mocked(prisma.dispute.update).mockResolvedValue({ status: 'resolved_refund' } as never);

      await resolveDispute(MOCK_DISPUTE_ID, 'admin-1', 'refund', 'Customer is right');

      expect(processRefund).toHaveBeenCalledWith(MOCK_BOOKING_ID, 1500, 'Customer is right');
      expect(prisma.dispute.update).toHaveBeenCalledWith({
        where: { id: MOCK_DISPUTE_ID },
        data: expect.objectContaining({ status: 'resolved_refund', resolutionNote: 'Customer is right', resolvedBy: 'admin-1' })
      });
    });

    it('rejects the dispute without processing a refund when resolution is reject', async () => {
      const mockDispute = { id: MOCK_DISPUTE_ID, status: 'open', bookingId: MOCK_BOOKING_ID, booking: { totalAmount: 1500 } };

      vi.mocked(prisma.dispute.findUnique).mockResolvedValue(mockDispute as never);
      vi.mocked(prisma.dispute.update).mockResolvedValue({ status: 'resolved_rejected' } as never);

      await resolveDispute(MOCK_DISPUTE_ID, 'admin-1', 'reject', 'Insufficient evidence');

      expect(processRefund).not.toHaveBeenCalled();
      expect(prisma.dispute.update).toHaveBeenCalledWith({
        where: { id: MOCK_DISPUTE_ID },
        data: expect.objectContaining({ status: 'resolved_rejected', resolutionNote: 'Insufficient evidence', resolvedBy: 'admin-1' })
      });
    });
  });
});
