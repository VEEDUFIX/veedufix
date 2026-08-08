import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma, PaymentStatus } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: vi.fn() },
    payment: { findFirst: vi.fn() },
    refund: { create: vi.fn(), update: vi.fn(), findUnique: vi.fn(), findMany: vi.fn(), count: vi.fn() },
  },
}));

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
}));

const { mockRazorpayRefund } = vi.hoisted(() => ({
  mockRazorpayRefund: vi.fn()
}));
vi.mock('razorpay', () => {
  return {
    default: class {
      payments = { refund: mockRazorpayRefund };
    }
  };
});

vi.mock('../config/env.js', () => ({
  env: {
    RAZORPAY_KEY_ID: 'test_key',
    RAZORPAY_KEY_SECRET: 'test_secret',
  },
}));

// ─── Imports ──────────────────────────────────────────────────────────────────

import {
  processRefund,
  retryRefund,
  getAllRefunds,
  listRefunds,
  bulkRetryFailedRefunds,
  exportRefundsCsv,
  RefundNotFoundError,
  RefundConflictError
} from '../modules/refund/refund.service.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';

describe('Refund Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('processRefund', () => {
    it('creates a processed refund when Razorpay refund succeeds', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({ id: 'b1', code: 'B-123' } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        id: 'p1', notes: { paymentId: 'pay_123' }, providerRef: 'pay_123'
      } as any);
      
      mockRazorpayRefund.mockResolvedValue({ id: 'rfnd_123' });

      vi.mocked(prisma.refund.create).mockImplementation((async (args: any) => ({ ...args.data, id: 'r1' })) as any);

      const res = await processRefund('b1', 100, 'Customer requested');
      
      expect(res.status).toBe('processed');
      expect(res.razorpayRefundId).toBe('rfnd_123');
      expect(mockRazorpayRefund).toHaveBeenCalledWith('pay_123', expect.objectContaining({ amount: 10000 })); // 100 rupees = 10000 paise
    });

    it('creates a failed refund when Razorpay refund fails', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({ id: 'b1', code: 'B-123' } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        id: 'p1', notes: { paymentId: 'pay_123' }, providerRef: 'pay_123'
      } as any);
      
      mockRazorpayRefund.mockRejectedValue(new Error('Razorpay error'));

      vi.mocked(prisma.refund.create).mockImplementation((async (args: any) => ({ ...args.data, id: 'r1' })) as any);

      const res = await processRefund('b1', 100, 'Customer requested');
      
      expect(res.status).toBe('failed');
      expect(res.failureReason).toBe('Razorpay error');
    });

    it('throws AppError.notFound if booking does not exist', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(null);
      
      await expect(processRefund('invalid', 100, 'Reason')).rejects.toSatisfy(
        (err: any) => err instanceof AppError && err.statusCode === 404
      );
    });
  });

  describe('retryRefund', () => {
    it('retries a failed refund successfully', async () => {
      vi.mocked(prisma.refund.findUnique).mockResolvedValue({
        id: 'r1', bookingId: 'b1', amount: 100, status: 'failed', reason: 'Failed once'
      } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        id: 'p1', notes: { paymentId: 'pay_123' }
      } as any);
      mockRazorpayRefund.mockResolvedValue({ id: 'rfnd_456' });
      vi.mocked(prisma.refund.update).mockImplementation((async (args: any) => ({ ...args.data, id: 'r1' })) as any);

      const res = await retryRefund('r1');
      expect(res.status).toBe('processed');
      expect(res.razorpayRefundId).toBe('rfnd_456');
      expect(prisma.refund.update).toHaveBeenCalledTimes(2); // one for pending, one for processed
    });

    it('throws if refund is not failed', async () => {
      vi.mocked(prisma.refund.findUnique).mockResolvedValue({
        id: 'r1', status: 'processed'
      } as any);

      await expect(retryRefund('r1')).rejects.toThrow(RefundConflictError);
    });
  });

  describe('getAllRefunds & listRefunds', () => {
    it('gets refunds with pagination', async () => {
      vi.mocked(prisma.refund.findMany).mockResolvedValue([{ id: 'r1', booking: {} }] as any);
      vi.mocked(prisma.refund.count).mockResolvedValue(1);

      const res = await getAllRefunds({ page: 1, pageSize: 10 });
      expect(res.total).toBe(1);
      expect(res.items[0].id).toBe('r1');
    });
  });

  describe('bulkRetryFailedRefunds', () => {
    it('retries all failed refunds', async () => {
      vi.mocked(prisma.refund.findMany).mockResolvedValue([{ id: 'r1' }, { id: 'r2' }] as any);
      
      // mock retryRefund internally, but we can just mock findUnique to return failed -> processed
      // Wait, we are testing the service itself. We already mocked findUnique.
      // We need it to return failed first, then processed for the result check.
      let callCount = 0;
      vi.mocked(prisma.refund.findUnique).mockImplementation((async () => {
        callCount++;
        if (callCount % 2 === 1) { // First call inside retryRefund
          return { id: 'r1', bookingId: 'b1', amount: 100, status: 'failed', reason: 'Failed once' };
        } else { // Second call inside bulkRetryFailedRefunds to check status
          return { status: 'processed' };
        }
      }) as any);
      
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({ notes: { paymentId: 'pay_123' } } as any);
      mockRazorpayRefund.mockResolvedValue({ id: 'rfnd_123' });
      
      const res = await bulkRetryFailedRefunds();
      expect(res.attempted).toBe(2);
      expect(res.succeeded).toBe(2);
    });
  });

  describe('exportRefundsCsv', () => {
    it('exports to csv format', async () => {
      vi.mocked(prisma.refund.findMany).mockResolvedValue([{
        id: 'r1', booking: { code: 'B-1', customer: { name: 'John' } }, amount: 10000, reason: 'Test', status: 'processed', createdAt: new Date('2024-01-01T00:00:00Z')
      }] as any);

      const csv = await exportRefundsCsv();
      expect(csv).toContain('ID,Booking Code,Customer Name,Amount (Rs.),Reason,Status,Failure Reason,Created At');
      expect(csv).toContain('r1,B-1,John,100.00,"Test",processed,"",2024-01-01T00:00:00.000Z');
    });
  });
});
