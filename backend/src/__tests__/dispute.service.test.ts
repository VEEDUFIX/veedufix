/**
 * Unit tests for dispute.service — 48-hour dispute grace period logic.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: vi.fn(), findMany: vi.fn() },
    dispute: { create: vi.fn(), findFirst: vi.fn(), findUnique: vi.fn(), findMany: vi.fn(), count: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
    disputeEvent: { create: vi.fn(), findFirst: vi.fn(), findMany: vi.fn() },
    bookingDiagnosticPhoto: { updateMany: vi.fn() },
    notification: { create: vi.fn() },
    refund: { update: vi.fn() },
    user: { findMany: vi.fn() },
    $transaction: vi.fn()
  },
}));

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn(), debug: vi.fn() },
}));

vi.mock('../lib/realtime.js', () => ({
  publishNotificationEvent: vi.fn(),
}));

vi.mock('../modules/refund/refund.service.js', () => ({
  getRemainingOriginalBookingChargeAmount: vi.fn(),
  processRefund: vi.fn(),
}));

vi.mock('../modules/matching/matching.service.js', () => ({
  assertAssignedPartnerAvailableForRemedy: vi.fn(),
  MatchingError: class MatchingError extends Error {},
}));

import { prisma } from '../lib/prisma.js';
import { publishNotificationEvent } from '../lib/realtime.js';
import { getRemainingOriginalBookingChargeAmount, processRefund } from '../modules/refund/refund.service.js';
import {
  raiseDispute,
  getCustomerDispute,
  resolveDispute,
  BookingNotFoundError,
  DisputeAccessError,
  DisputeValidationError,
  DisputeWindowExpiredError,
  DisputeConflictError,
  addDisputeMessage,
  completeClaimRework,
  updateDisputeClaim
} from '../modules/dispute/dispute.service.js';

// ─── Test Data ────────────────────────────────────────────────────────────────

const MOCK_BOOKING_ID = 'book-123';
const MOCK_CUSTOMER_ID = 'cust-123';
const MOCK_DISPUTE_ID = 'disp-123';

const mockBookingEvidence = (completedAt: Date) => ({
  id: MOCK_BOOKING_ID,
  code: 'BK-0001',
  status: 'COMPLETED',
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
    vi.mocked(prisma.$transaction).mockImplementation(async (callback) =>
      callback(prisma as never) as never
    );
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('returns deleted booked-service rows in customer dispute options', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      customerId: MOCK_CUSTOMER_ID,
      status: 'COMPLETED',
      services: [{
        id: 'booking-service-deleted',
        serviceId: null,
        service: null,
        guaranteePolicySnapshot: { enabled: true, claimWindowDays: 14 }
      }],
      jobExecution: { completedAt: new Date(), status: 'completed' }
    } as never);
    vi.mocked(prisma.dispute.findFirst).mockResolvedValue(null);
    vi.mocked(prisma.disputeEvent.findMany).mockResolvedValue([] as never);

    const result = await getCustomerDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID);

    expect(result.serviceOptions).toEqual([{
      bookingServiceId: 'booking-service-deleted',
      serviceId: null,
      serviceName: 'Removed service',
      policy: { enabled: true, claimWindowDays: 14 }
    }]);
  });

  it.each(['open', 'under_review', 'action_required', 'approved', 'refund_pending', 'resolved_rework'])(
    'does not allow another claim while the latest claim is %s',
    async (status) => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        customerId: MOCK_CUSTOMER_ID,
        status: 'COMPLETED',
        services: [],
        jobExecution: { completedAt: new Date(), status: 'completed' }
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status
      } as never);
      vi.mocked(prisma.disputeEvent.findMany).mockResolvedValue([] as never);

      const result = await getCustomerDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID);

      expect(result.canSubmit).toBe(false);
    }
  );

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
      vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mockResolvedValue({ count: 1 } as never);
      
      const mockDispute = { id: MOCK_DISPUTE_ID, bookingId: MOCK_BOOKING_ID, status: 'open', reason: 'Poor work' };
      vi.mocked(prisma.dispute.create).mockResolvedValue(mockDispute as never);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin-1' }] as never);
      vi.mocked(prisma.notification.create).mockResolvedValue({ id: 'notification-1' } as never);
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue(null as never);

      const result = await raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor work', {
        evidencePhotoIds: ['photo-1']
      });

      expect(result.id).toBe(MOCK_DISPUTE_ID);
      expect(prisma.dispute.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          bookingId: MOCK_BOOKING_ID,
          raisedBy: MOCK_CUSTOMER_ID,
          reason: 'Poor work',
          status: 'open',
          issueCategory: null,
          evidencePhotoIds: ['photo-1'],
          idempotencyKey: null,
          referenceCode: expect.stringMatching(/^CL-/)
        })
      });
      expect(prisma.bookingDiagnosticPhoto.updateMany).toHaveBeenCalledWith({
        where: {
          id: { in: ['photo-1'] },
          uploadedById: MOCK_CUSTOMER_ID,
          bookingId: null,
          publicId: { not: { startsWith: 'reservation:' } },
          expiresAt: { gt: expect.any(Date) }
        },
        data: { bookingId: MOCK_BOOKING_ID, expiresAt: null }
      });
      expect(prisma.disputeEvent.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          disputeId: MOCK_DISPUTE_ID,
          actorId: MOCK_CUSTOMER_ID,
          actorRole: 'CUSTOMER',
          type: 'submitted',
          visibility: 'CUSTOMER'
        })
      });
      expect(publishNotificationEvent).toHaveBeenCalledOnce();
    });

    it('rejects a configured service guarantee that has no eligible issue categories', async () => {
      vi.setSystemTime(new Date('2026-08-01T12:00:00Z'));
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBookingEvidence(new Date('2026-08-01T10:00:00Z')),
        services: [{ serviceId: 'service-1', guaranteePolicySnapshot: {
          enabled: true, claimWindowDays: 14, issueCategories: [], evidenceRequired: false
        } }]
      } as never);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor workmanship', {
        serviceId: 'service-1', issueCategory: 'workmanship'
      })).rejects.toThrow(DisputeValidationError);
      expect(prisma.dispute.create).not.toHaveBeenCalled();
    });

    it('uses a guarantee snapshot when its booked service was deleted', async () => {
      const now = new Date('2026-08-01T12:00:00Z');
      vi.setSystemTime(now);
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBookingEvidence(new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000)),
        services: [{
          serviceId: null,
          guaranteePolicySnapshot: {
            enabled: true,
            claimWindowDays: 14,
            issueCategories: ['workmanship'],
            evidenceRequired: false
          }
        }]
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.dispute.create).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'open',
        reason: 'Poor workmanship'
      } as never);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin-1' }] as never);
      vi.mocked(prisma.notification.create).mockResolvedValue({ id: 'notification-1' } as never);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor workmanship', {
        issueCategory: 'workmanship'
      })).resolves.toBeDefined();
      expect(prisma.dispute.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ serviceId: null })
      }));
    });

    it('infers the only enabled policy when a different booked service was deleted or has no guarantee', async () => {
      const now = new Date('2026-08-01T12:00:00Z');
      vi.setSystemTime(now);
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBookingEvidence(new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000)),
        services: [
          {
            id: 'booking-service-deleted',
            serviceId: null,
            guaranteePolicySnapshot: {
              enabled: true,
              claimWindowDays: 14,
              issueCategories: ['workmanship'],
              evidenceRequired: false
            }
          },
          {
            id: 'booking-service-other',
            serviceId: 'service-2',
            guaranteePolicySnapshot: { enabled: false }
          }
        ]
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.dispute.create).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'open',
        reason: 'Poor workmanship'
      } as never);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin-1' }] as never);
      vi.mocked(prisma.notification.create).mockResolvedValue({ id: 'notification-1' } as never);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor workmanship', {
        issueCategory: 'workmanship'
      })).resolves.toBeDefined();
      expect(prisma.dispute.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ serviceId: null })
      }));
    });

    it('keeps the legacy 48-hour claim window for a booking with a disabled guarantee snapshot', async () => {
      const now = new Date('2026-08-01T12:00:00Z');
      vi.setSystemTime(now);
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBookingEvidence(new Date(now.getTime() - 10 * 60 * 60 * 1000)),
        services: [{ serviceId: 'service-1', guaranteePolicySnapshot: { enabled: false } }]
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.dispute.create).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'open',
        reason: 'Poor work'
      } as never);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin-1' }] as never);
      vi.mocked(prisma.notification.create).mockResolvedValue({ id: 'notification-1' } as never);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor work', {
        serviceId: 'service-1',
        issueCategory: 'poor_workmanship'
      })).resolves.toBeDefined();
    });

    it('keeps the legacy claim path for older clients on multi-service bookings without an enabled policy', async () => {
      vi.setSystemTime(new Date('2026-08-01T12:00:00Z'));
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBookingEvidence(new Date('2026-08-01T10:00:00Z')),
        services: [
          { serviceId: 'service-1', guaranteePolicySnapshot: null },
          { serviceId: 'service-2', guaranteePolicySnapshot: { enabled: false } }
        ]
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.dispute.create).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'open',
        reason: 'Poor work'
      } as never);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin-1' }] as never);
      vi.mocked(prisma.notification.create).mockResolvedValue({ id: 'notification-1' } as never);

      await expect(
        raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor work')
      ).resolves.toBeDefined();
      expect(prisma.dispute.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ serviceId: null })
      }));
    });

    it('ignores null-service rows without a guarantee snapshot when selecting a legacy claim service', async () => {
      vi.setSystemTime(new Date('2026-08-01T12:00:00Z'));
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBookingEvidence(new Date('2026-08-01T10:00:00Z')),
        services: [
          { serviceId: null, guaranteePolicySnapshot: null },
          { serviceId: 'service-1', guaranteePolicySnapshot: { enabled: false } }
        ]
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.dispute.create).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'open',
        reason: 'Poor work'
      } as never);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin-1' }] as never);
      vi.mocked(prisma.notification.create).mockResolvedValue({ id: 'notification-1' } as never);

      await expect(
        raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor work')
      ).resolves.toBeDefined();
      expect(prisma.dispute.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ serviceId: 'service-1' })
      }));
    });

    it('blocks a second claim while corrective work awaits Customer confirmation', async () => {
      vi.setSystemTime(new Date('2026-08-01T12:00:00Z'));
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBookingEvidence(new Date('2026-08-01T10:00:00Z')),
        services: []
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue({ id: 'active-rework', status: 'resolved_rework' } as never);

      await expect(raiseDispute(MOCK_BOOKING_ID, MOCK_CUSTOMER_ID, 'Poor workmanship'))
        .rejects.toThrow(DisputeConflictError);
      expect(prisma.dispute.findFirst).toHaveBeenCalledWith(expect.objectContaining({
        where: expect.objectContaining({ status: { in: expect.arrayContaining(['resolved_rework']) } })
      }));
    });
  });

  describe('participant dispute history visibility', () => {
    it('filters internal admin notes from Partner corrective-work responses', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        worker: { userId: 'partner-1' }
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'approved',
        remedyStatus: 'scheduled',
        reworkScheduledAt: new Date(0)
      } as never);
      vi.mocked(prisma.disputeEvent.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.dispute.updateMany).mockResolvedValue({ count: 1 } as never);
      vi.mocked(prisma.disputeEvent.create).mockResolvedValue({ id: 'event-1' } as never);
      vi.mocked(prisma.dispute.findUnique)
        .mockResolvedValueOnce({
          bookingId: MOCK_BOOKING_ID,
          booking: { customerId: MOCK_CUSTOMER_ID, worker: { userId: 'partner-1' } }
        } as never)
        .mockResolvedValueOnce({
          id: MOCK_DISPUTE_ID,
          history: [
            { visibility: 'INTERNAL', message: 'Admin-only note' },
            { visibility: 'CUSTOMER', message: 'Visible response' }
          ],
          booking: { id: MOCK_BOOKING_ID, code: 'BK-0001' }
        } as never);

      await completeClaimRework({
        bookingId: MOCK_BOOKING_ID,
        workerUserId: 'partner-1',
        message: 'Corrective work completed',
        idempotencyKey: 'partner-rework-complete-1'
      });

      expect(prisma.dispute.findUnique).toHaveBeenLastCalledWith(expect.objectContaining({
        where: { id: MOCK_DISPUTE_ID },
        include: expect.objectContaining({
          history: expect.objectContaining({
            where: { visibility: { in: ['CUSTOMER', 'PARTNER'] } }
          })
        })
      }));
    });
  });

  describe('claim lifecycle safeguards', () => {
    it('returns the Partner to review when the Customer responds to an information request', async () => {
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'action_required',
        booking: { customerId: MOCK_CUSTOMER_ID, worker: { userId: 'partner-user' } }
      } as never);
      vi.mocked(prisma.disputeEvent.findFirst).mockResolvedValue(null as never);
      vi.mocked(prisma.dispute.updateMany).mockResolvedValue({ count: 1 } as never);
      vi.mocked(prisma.disputeEvent.create).mockResolvedValue({
        id: 'event-1', type: 'customer_response', actorId: MOCK_CUSTOMER_ID, message: 'More details'
      } as never);

      const event = await addDisputeMessage({
        bookingId: MOCK_BOOKING_ID,
        userId: MOCK_CUSTOMER_ID,
        role: 'CUSTOMER',
        message: 'More details',
        idempotencyKey: 'customer-response-1'
      });

      expect(event.type).toBe('customer_response');
      expect(prisma.dispute.updateMany).toHaveBeenCalledWith({
        where: { id: MOCK_DISPUTE_ID, status: 'action_required' },
        data: { status: 'under_review' }
      });
    });

    it('prevents corrective work completion before Admin scheduling', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        worker: { userId: 'partner-user' }
      } as never);
      vi.mocked(prisma.dispute.findFirst).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        status: 'approved',
        remedyStatus: 'awaiting_admin_schedule',
        booking: { worker: { userId: 'partner-user' } }
      } as never);

      await expect(completeClaimRework({
        bookingId: MOCK_BOOKING_ID,
        workerUserId: 'partner-user',
        message: 'Work done',
        idempotencyKey: 'complete-before-schedule'
      })).rejects.toThrow(DisputeConflictError);
      expect(prisma.dispute.updateMany).not.toHaveBeenCalled();
    });

    it('does not allow customer-visible visibility to be changed to internal on an action', async () => {
      await expect(updateDisputeClaim({
        disputeId: MOCK_DISPUTE_ID,
        adminId: 'admin-1',
        action: 'request_info',
        message: 'Please send details',
        visibility: 'INTERNAL'
      })).rejects.toThrow(DisputeValidationError);
      expect(prisma.dispute.findUnique).not.toHaveBeenCalled();
    });

    it('defaults an internal note without visibility to INTERNAL', async () => {
      const dispute = {
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'open',
        remedyStatus: null,
        serviceId: null,
        history: [],
        booking: { services: [] },
      };
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue(dispute as never);
      vi.mocked(prisma.disputeEvent.create).mockResolvedValue({ id: 'event-1' } as never);

      await updateDisputeClaim({
        disputeId: MOCK_DISPUTE_ID,
        adminId: 'admin-1',
        action: 'internal_note',
        message: 'Reviewed supporting documents.',
      });

      expect(prisma.disputeEvent.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ visibility: 'INTERNAL', type: 'internal_note' }),
      });
    });

    it('defaults an omitted visibility to CUSTOMER for customer-facing actions', async () => {
      const dispute = {
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'open',
        remedyStatus: null,
        serviceId: null,
        history: [],
        booking: { services: [] },
      };
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue(dispute as never);
      vi.mocked(prisma.dispute.updateMany).mockResolvedValue({ count: 1 } as never);
      vi.mocked(prisma.disputeEvent.create).mockResolvedValue({ id: 'event-1' } as never);

      await updateDisputeClaim({
        disputeId: MOCK_DISPUTE_ID,
        adminId: 'admin-1',
        action: 'request_info',
        message: 'Please provide another photo.',
      });

      expect(prisma.disputeEvent.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ visibility: 'CUSTOMER', type: 'request_info' }),
      });
    });

    it('does not allow requesting information after a remedy is approved', async () => {
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'approved',
        remedyStatus: 'awaiting_partner_proposal',
        serviceId: null,
        history: [],
        booking: { services: [] },
      } as never);

      await expect(updateDisputeClaim({
        disputeId: MOCK_DISPUTE_ID,
        adminId: 'admin-1',
        action: 'request_info',
        message: 'Please provide another photo.',
      })).rejects.toThrow('Information cannot be requested after a remedy is approved');

      expect(prisma.dispute.updateMany).not.toHaveBeenCalled();
      expect(prisma.disputeEvent.create).not.toHaveBeenCalled();
    });

    it('allows an Admin to close a completed corrective-work claim', async () => {
      const dispute = {
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'resolved_rework',
        remedyStatus: 'completed',
        serviceId: null,
        history: [],
        booking: { services: [] },
      };
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue(dispute as never);
      vi.mocked(prisma.dispute.updateMany).mockResolvedValue({ count: 1 } as never);
      vi.mocked(prisma.disputeEvent.create).mockResolvedValue({ id: 'event-1' } as never);

      await updateDisputeClaim({
        disputeId: MOCK_DISPUTE_ID,
        adminId: 'admin-1',
        action: 'close',
        message: 'Closing the completed corrective-work claim.',
      });

      expect(prisma.dispute.updateMany).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: MOCK_DISPUTE_ID, status: 'resolved_rework' },
        data: expect.objectContaining({ status: 'closed', resolvedBy: 'admin-1' }),
      }));
      expect(prisma.disputeEvent.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ type: 'close', actorRole: 'ADMIN' }),
      }));
    });

    it('uses the only enabled policy when a deleted service has a remedy on a multi-service booking', async () => {
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        bookingId: MOCK_BOOKING_ID,
        status: 'open',
        remedyStatus: null,
        serviceId: null,
        history: [],
        booking: {
          services: [
            {
              serviceId: null,
              guaranteePolicySnapshot: { enabled: true, resolutionTypes: ['REWORK'] }
            },
            { serviceId: 'service-2', guaranteePolicySnapshot: { enabled: false } }
          ]
        }
      } as never);
      vi.mocked(prisma.dispute.updateMany).mockResolvedValue({ count: 1 } as never);
      vi.mocked(prisma.disputeEvent.create).mockResolvedValue({ id: 'event-1' } as never);

      await updateDisputeClaim({
        disputeId: MOCK_DISPUTE_ID,
        adminId: 'admin-1',
        action: 'approve_rework',
        message: 'Approve corrective work'
      });

      expect(prisma.dispute.updateMany).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: MOCK_DISPUTE_ID, status: 'open' },
        data: expect.objectContaining({ status: 'approved' })
      }));
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
      vi.mocked(getRemainingOriginalBookingChargeAmount).mockResolvedValue(700);
      vi.mocked(processRefund).mockResolvedValue({ id: 'ref-1', status: 'pending' } as never);
      vi.mocked(prisma.dispute.updateMany).mockResolvedValue({ count: 1 } as never);
      vi.mocked(prisma.dispute.update).mockResolvedValue({ status: 'resolved_refund' } as never);

      await resolveDispute(MOCK_DISPUTE_ID, 'admin-1', 'refund', 'Customer is right');

      expect(processRefund).toHaveBeenCalledWith(MOCK_BOOKING_ID, 700, 'Customer is right', MOCK_DISPUTE_ID);
      expect(prisma.dispute.updateMany).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: MOCK_DISPUTE_ID, status: { in: ['open', 'under_review', 'action_required'] } },
        data: expect.objectContaining({ status: 'refund_pending' })
      }));
      expect(prisma.dispute.updateMany).toHaveBeenCalledWith({
        where: { id: MOCK_DISPUTE_ID, OR: [{ refundId: null }, { refundId: 'ref-1' }] },
        data: { refundId: 'ref-1' }
      });
      expect(prisma.dispute.updateMany).toHaveBeenCalledWith({
        where: { id: MOCK_DISPUTE_ID, status: 'refund_pending' },
        data: expect.objectContaining({ status: 'refund_pending' })
      });
    });

    it('enforces the only booked service policy when the claim service was deleted', async () => {
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        status: 'open',
        serviceId: null,
        bookingId: MOCK_BOOKING_ID,
        booking: {
          totalAmount: 1500,
          services: [{
            serviceId: null,
            guaranteePolicySnapshot: { enabled: true, resolutionTypes: ['REWORK'] }
          }]
        }
      } as never);

      await expect(
        resolveDispute(MOCK_DISPUTE_ID, 'admin-1', 'refund', 'Customer is right')
      ).rejects.toThrow('A refund review is not permitted');
      expect(processRefund).not.toHaveBeenCalled();
      expect(prisma.dispute.updateMany).not.toHaveBeenCalled();
    });

    it('uses the only enabled policy for refunds on multi-service bookings with a deleted service', async () => {
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue({
        id: MOCK_DISPUTE_ID,
        status: 'open',
        serviceId: null,
        bookingId: MOCK_BOOKING_ID,
        booking: {
          totalAmount: 1500,
          services: [
            {
              serviceId: null,
              guaranteePolicySnapshot: { enabled: true, resolutionTypes: ['REWORK'] }
            },
            { serviceId: 'service-2', guaranteePolicySnapshot: { enabled: false } }
          ]
        }
      } as never);

      await expect(
        resolveDispute(MOCK_DISPUTE_ID, 'admin-1', 'refund', 'Customer is right')
      ).rejects.toThrow('A refund review is not permitted');
      expect(processRefund).not.toHaveBeenCalled();
    });

    it('rejects the dispute without processing a refund when resolution is reject', async () => {
      const mockDispute = { id: MOCK_DISPUTE_ID, status: 'open', bookingId: MOCK_BOOKING_ID, booking: { totalAmount: 1500 } };

      vi.mocked(prisma.dispute.findUnique).mockResolvedValue(mockDispute as never);
      vi.mocked(prisma.dispute.updateMany).mockResolvedValue({ count: 1 } as never);

      await resolveDispute(MOCK_DISPUTE_ID, 'admin-1', 'reject', 'Insufficient evidence');

      expect(processRefund).not.toHaveBeenCalled();
      expect(prisma.dispute.updateMany).toHaveBeenCalledWith({
        where: { id: MOCK_DISPUTE_ID, status: { in: ['open', 'under_review', 'action_required'] } },
        data: expect.objectContaining({ status: 'resolved_rejected', resolutionNote: 'Insufficient evidence', resolvedBy: 'admin-1' })
      });
    });

    it('rejects the dispute if another admin resolved it after the initial read', async () => {
      const mockDispute = { id: MOCK_DISPUTE_ID, status: 'open', bookingId: MOCK_BOOKING_ID, booking: { totalAmount: 1500 } };
      vi.mocked(prisma.dispute.findUnique).mockResolvedValue(mockDispute as never);
      vi.mocked(prisma.dispute.updateMany).mockResolvedValue({ count: 0 } as never);

      await expect(resolveDispute(MOCK_DISPUTE_ID, 'admin-1', 'reject', 'Insufficient evidence'))
        .rejects.toThrow(DisputeConflictError);
    });
  });
});
