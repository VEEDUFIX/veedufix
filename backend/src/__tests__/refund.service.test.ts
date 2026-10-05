import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma, PaymentStatus } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => {
  const prisma: any = {
    booking: { findUnique: vi.fn(), update: vi.fn() },
    payment: { findFirst: vi.fn(), updateMany: vi.fn() },
    refund: {
      create: vi.fn(), update: vi.fn(), updateMany: vi.fn(), findUnique: vi.fn(),
      findMany: vi.fn(), count: vi.fn(), aggregate: vi.fn()
    },
    dispute: { updateMany: vi.fn() },
    user: { update: vi.fn() },
    walletTransaction: { create: vi.fn() }
  };
  prisma.$transaction = vi.fn((callback: (tx: any) => unknown) =>
    callback({ ...prisma, $queryRaw: vi.fn() })
  );
  return { prisma };
});

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
  settleRefundFromProvider,
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
    vi.mocked(prisma.refund.findMany).mockResolvedValue([] as any);
    vi.mocked(prisma.refund.updateMany).mockResolvedValue({ count: 1 } as any);
  });

  describe('settleRefundFromProvider', () => {
    it('ignores a stale provider attempt before applying settlement', async () => {
      const activeRefund = {
        id: 'r1',
        bookingId: 'b1',
        status: 'pending',
        razorpayRefundId: 'rfnd-current',
        providerAttemptId: 'attempt-current',
        walletAmount: new Prisma.Decimal(100),
        walletCreditedAt: null,
        booking: { customerId: 'c1' }
      };
      vi.mocked(prisma.refund.findUnique)
        .mockResolvedValueOnce(activeRefund as any)
        .mockResolvedValueOnce(activeRefund as any);

      const result = await settleRefundFromProvider('r1', true, undefined, {
        providerRefundId: 'rfnd-stale',
        providerAttemptId: 'attempt-stale'
      });

      expect(result).toBeNull();
      expect(prisma.refund.update).not.toHaveBeenCalled();
      expect(prisma.user.update).not.toHaveBeenCalled();
      expect(prisma.walletTransaction.create).not.toHaveBeenCalled();
    });
  });

  describe('processRefund', () => {
    it('creates a processed refund when Razorpay refund succeeds', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({ id: 'b1', code: 'B-123' } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        id: 'p1', notes: { paymentId: 'pay_123', walletDeductAmountPaise: 0 }, providerRef: 'pay_123', amount: new Prisma.Decimal(100),
        booking: { id: 'b1', code: 'B-123', customerId: 'c1', totalAmount: new Prisma.Decimal(100) }
      } as any);
      
      mockRazorpayRefund.mockResolvedValue({ id: 'rfnd_123' });

      vi.mocked(prisma.refund.create).mockImplementation((async (args: any) => ({ ...args.data, id: 'r1' })) as any);
      vi.mocked(prisma.refund.findUnique).mockResolvedValue({ id: 'r1', status: 'pending', razorpayRefundId: 'rfnd_123' } as any);

      const res = await processRefund('b1', 100, 'Customer requested');
      
      expect(res.status).toBe('pending');
      expect(res.razorpayRefundId).toBe('rfnd_123');
      expect(mockRazorpayRefund).toHaveBeenCalledWith('pay_123', expect.objectContaining({ amount: 10000 })); // 100 rupees = 10000 paise
    });

    it('creates a failed refund when Razorpay refund fails', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({ id: 'b1', code: 'B-123' } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        id: 'p1', notes: { paymentId: 'pay_123', walletDeductAmountPaise: 0 }, providerRef: 'pay_123', amount: new Prisma.Decimal(100),
        booking: { id: 'b1', code: 'B-123', customerId: 'c1', totalAmount: new Prisma.Decimal(100) }
      } as any);
      
      mockRazorpayRefund.mockRejectedValue(new Error('Razorpay error'));

      vi.mocked(prisma.refund.create).mockImplementation((async (args: any) => ({ ...args.data, id: 'r1' })) as any);
      vi.mocked(prisma.refund.findUnique).mockResolvedValue({ id: 'r1', status: 'failed', failureReason: 'Razorpay error' } as any);

      const res = await processRefund('b1', 100, 'Customer requested');
      
      expect(res.status).toBe('failed');
      expect(res.failureReason).toBe('Razorpay error');
    });

    it('keeps a refund pending for reconciliation when persisting an accepted provider result throws', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({ id: 'b1', code: 'B-123' } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        id: 'p1', notes: { paymentId: 'pay_123', walletDeductAmountPaise: 0 }, amount: new Prisma.Decimal(100),
        booking: { id: 'b1', code: 'B-123', customerId: 'c1', totalAmount: new Prisma.Decimal(100) }
      } as any);
      vi.mocked(prisma.refund.create).mockImplementation((async (args: any) => ({ ...args.data, id: 'r1' })) as any);
      mockRazorpayRefund.mockResolvedValue({ id: 'rfnd_123' });
      vi.mocked(prisma.refund.updateMany)
        .mockRejectedValueOnce(new Error('Refund status write failed'))
        .mockResolvedValueOnce({ count: 1 } as any);

      await expect(processRefund('b1', 100, 'Customer requested'))
        .rejects.toThrow('Refund status write failed');

      expect(prisma.refund.updateMany).toHaveBeenNthCalledWith(2, {
        where: { id: 'r1', status: 'pending' },
        data: { failureReason: 'Provider outcome requires reconciliation: Refund status write failed' }
      });
    });

    it('does not send a refund larger than the captured Razorpay amount', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({ id: 'b1', code: 'B-123' } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        id: 'p1',
        notes: { paymentId: 'pay_123', walletDeductAmountPaise: 0 },
        providerRef: 'order_123',
        amount: new Prisma.Decimal(50),
        booking: { id: 'b1', code: 'B-123', customerId: 'c1', totalAmount: new Prisma.Decimal(100) }
      } as any);
      vi.mocked(prisma.refund.create).mockImplementation((async (args: any) => ({ ...args.data, id: 'r1' })) as any);
      vi.mocked(prisma.refund.findUnique).mockResolvedValue({ id: 'r1', status: 'pending', razorpayRefundId: 'rfnd_123' } as any);

      await expect(processRefund('b1', 100, 'Customer requested')).rejects.toSatisfy(
        (err: any) => err instanceof AppError && err.statusCode === 409
      );
      expect(mockRazorpayRefund).not.toHaveBeenCalled();
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
        id: 'p1', notes: { paymentId: 'pay_123', walletDeductAmountPaise: 0 }, amount: new Prisma.Decimal(100),
        booking: { id: 'b1', code: 'B-123', customerId: 'c1', totalAmount: new Prisma.Decimal(100) }
      } as any);
      mockRazorpayRefund.mockResolvedValue({ id: 'rfnd_456' });
      vi.mocked(prisma.refund.update).mockImplementation((async (args: any) => ({ ...args.data, id: 'r1' })) as any);
      vi.mocked(prisma.refund.findUnique)
        .mockResolvedValueOnce({ id: 'r1', bookingId: 'b1', amount: 100, status: 'failed', reason: 'Failed once' } as any)
        .mockResolvedValueOnce({ id: 'r1', status: 'pending', razorpayRefundId: 'rfnd_456' } as any);

      const res = await retryRefund('r1');
      expect(res.status).toBe('pending');
      expect(res.razorpayRefundId).toBe('rfnd_456');
      expect(prisma.refund.update).not.toHaveBeenCalled();
      expect(prisma.refund.updateMany).toHaveBeenCalledTimes(2); // atomically claim, then persist provider result
      expect(prisma.refund.updateMany).toHaveBeenNthCalledWith(1, expect.objectContaining({
        where: { id: 'r1', status: 'failed' },
        data: expect.objectContaining({
          status: 'pending',
          failureReason: null,
          razorpayRefundId: null
        })
      }));
    });

    it('throws if refund is not failed', async () => {
      vi.mocked(prisma.refund.findUnique).mockResolvedValue({
        id: 'r1', status: 'processed'
      } as any);

      await expect(retryRefund('r1')).rejects.toThrow(RefundConflictError);
    });

    it('does not submit a retry when another admin already claimed it', async () => {
      vi.mocked(prisma.refund.findUnique).mockResolvedValue({
        id: 'r1', bookingId: 'b1', amount: 100, status: 'failed', reason: 'Failed once'
      } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        id: 'p1', notes: { paymentId: 'pay_123', walletDeductAmountPaise: 0 }, amount: new Prisma.Decimal(100),
        booking: { id: 'b1', code: 'B-123', customerId: 'c1', totalAmount: new Prisma.Decimal(100) }
      } as any);
      vi.mocked(prisma.refund.updateMany).mockResolvedValueOnce({ count: 0 } as any);

      await expect(retryRefund('r1')).rejects.toThrow(RefundConflictError);
      expect(mockRazorpayRefund).not.toHaveBeenCalled();
    });

    it('conditionally fails a retry when no captured payment remains', async () => {
      vi.mocked(prisma.refund.findUnique)
        .mockResolvedValueOnce({
          id: 'r1', bookingId: 'b1', amount: 100, status: 'failed', reason: 'Failed once'
        } as any)
        .mockResolvedValueOnce({ id: 'r1', status: 'failed' } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue(null);

      const result = await retryRefund('r1');

      expect(result.status).toBe('failed');
      expect(prisma.refund.updateMany).toHaveBeenNthCalledWith(2, {
        where: { id: 'r1', status: 'pending' },
        data: {
          status: 'failed',
          failureReason: 'No captured Razorpay payment was found for this booking'
        }
      });
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
      vi.mocked(prisma.refund.findMany).mockImplementation((async (args: any) =>
        args.where?.status === 'failed' ? [{ id: 'r1' }, { id: 'r2' }] : []
      ) as any);
      
      vi.mocked(prisma.refund.findUnique)
        .mockResolvedValueOnce({ id: 'r1', bookingId: 'b1', amount: 100, status: 'failed', reason: 'Failed once' } as any)
        .mockResolvedValueOnce({ id: 'r1', status: 'pending' } as any)
        .mockResolvedValueOnce({ id: 'r1', status: 'pending' } as any)
        .mockResolvedValueOnce({ id: 'r2', bookingId: 'b1', amount: 100, status: 'failed', reason: 'Failed once' } as any)
        .mockResolvedValueOnce({ id: 'r2', status: 'pending' } as any)
        .mockResolvedValueOnce({ id: 'r2', status: 'pending' } as any);
      vi.mocked(prisma.payment.findFirst).mockResolvedValue({
        notes: { paymentId: 'pay_123', walletDeductAmountPaise: 0 }, amount: new Prisma.Decimal(100),
        booking: { id: 'b1', code: 'B-123', customerId: 'c1', totalAmount: new Prisma.Decimal(100) }
      } as any);
      vi.mocked(prisma.refund.update).mockResolvedValue({ id: 'r1', status: 'pending' } as any);
      mockRazorpayRefund.mockResolvedValue({ id: 'rfnd_123' });
      
      const res = await bulkRetryFailedRefunds();
      expect(res.attempted).toBe(2);
      expect(mockRazorpayRefund).toHaveBeenCalledTimes(2);
      expect(res.succeeded).toBe(2);
    });
  });

  describe('exportRefundsCsv', () => {
    it('exports to csv format', async () => {
      vi.mocked(prisma.refund.findMany).mockResolvedValue([{
        id: 'r1', booking: { code: 'B-1', customer: { name: 'John' } }, amount: 100, reason: 'Test', status: 'processed', createdAt: new Date('2024-01-01T00:00:00Z')
      }] as any);

      const csv = await exportRefundsCsv();
      expect(csv).toContain('ID,Booking Code,Customer Name,Amount (Rs.),Reason,Status,Failure Reason,Created At');
      expect(csv).toContain('r1,B-1,John,100.00,"Test",processed,"",2024-01-01T00:00:00.000Z');
    });
  });
});
