import { describe, it, expect, vi, beforeEach } from 'vitest';
import { BookingStatus } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────
vi.mock('../lib/prisma.js', () => ({
  prisma: {
    opsAlert: { findMany: vi.fn(), count: vi.fn(), upsert: vi.fn() },
    user: { findMany: vi.fn() },
    jobExecution: { count: vi.fn() },
    booking: { count: vi.fn(), aggregate: vi.fn(), findMany: vi.fn() },
    workerProfile: { count: vi.fn() },
    dispute: { count: vi.fn() },
    supportTicket: { count: vi.fn() },
    payout: { count: vi.fn() },
    refund: { count: vi.fn() }
  }
}));

vi.mock('../lib/realtime.js', () => ({
  publishNotificationEvent: vi.fn()
}));

// ─── Imports ──────────────────────────────────────────────────────────────────
import { getOpsOverview, listOpsAlerts, raiseOpsAlert } from '../modules/ops/ops.service.js';
import { prisma } from '../lib/prisma.js';

describe('Ops Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('raiseOpsAlert', () => {
    it('creates or updates ops alert', async () => {
      vi.mocked(prisma.opsAlert.upsert).mockResolvedValue({
        id: 'alert1', sourceId: 'src1', type: 'dispatch_failure',
        message: 'Test message', metadata: {}, severity: 'high',
        status: 'open', createdAt: new Date()
      } as any);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin1' }] as any);

      const res = await raiseOpsAlert({
        type: 'dispatch_failure', sourceId: 'src1', message: 'Test message'
      });
      expect(res.id).toBe('alert1');
      expect(prisma.opsAlert.upsert).toHaveBeenCalled();
    });
  });

  describe('listOpsAlerts', () => {
    it('paginates and formats alerts', async () => {
      vi.mocked(prisma.opsAlert.findMany).mockResolvedValue([
        {
          id: 'alert1', sourceId: 'src1', type: 'dispatch_failure',
          message: 'Test message', metadata: { bookingCode: 'B-1' }, severity: 'high',
          status: 'open', createdAt: new Date()
        }
      ] as any);
      vi.mocked(prisma.opsAlert.count).mockResolvedValue(1);

      const res = await listOpsAlerts();
      expect(res.total).toBe(1);
      expect(res.items.length).toBe(1);
      expect(res.items[0].bookingCode).toBe('B-1');
    });
  });

  describe('getOpsOverview', () => {
    it('fetches counts and live jobs', async () => {
      vi.mocked(prisma.jobExecution.count).mockResolvedValue(5);
      vi.mocked(prisma.booking.count).mockResolvedValue(10);
      vi.mocked(prisma.workerProfile.count).mockResolvedValue(20);
      vi.mocked(prisma.booking.aggregate).mockResolvedValue({ _sum: { totalAmount: 1000 } } as any);
      vi.mocked(prisma.dispute.count).mockResolvedValue(2);
      vi.mocked(prisma.supportTicket.count).mockResolvedValue(3);
      vi.mocked(prisma.payout.count).mockResolvedValue(1);
      vi.mocked(prisma.refund.count).mockResolvedValue(0);
      
      vi.mocked(prisma.opsAlert.findMany).mockResolvedValue([]);
      vi.mocked(prisma.opsAlert.count).mockResolvedValue(0);

      vi.mocked(prisma.booking.findMany).mockResolvedValue([
        {
          id: 'b1', code: 'B-1', status: BookingStatus.IN_PROGRESS,
          customer: { name: 'Cust', avatarUrl: null },
          city: { name: 'Chennai' },
          services: [],
          jobExecution: {
            status: 'in_progress', createdAt: new Date(), updatedAt: new Date(),
            beforePhotos: [], afterPhotos: [], checklist: []
          }
        }
      ] as any);

      const res = await getOpsOverview();
      expect(res.summary.activeJobsCount).toBe(5);
      expect(res.summary.totalRevenue).toBe(1000);
      expect(res.summary.activeWorkersCount).toBe(20);
      expect(res.liveJobs.length).toBe(1);
      expect(res.liveJobs[0].customerName).toBe('Cust');
    });
  });
});
