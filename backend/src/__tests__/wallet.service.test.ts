import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn((cb) => cb(prismaMockTx)),
    user: { findUnique: vi.fn(), update: vi.fn() },
    referral: { findMany: vi.fn(), findFirst: vi.fn(), create: vi.fn() },
    walletTransaction: { findMany: vi.fn(), create: vi.fn(), update: vi.fn() },
  },
}));

const prismaMockTx = {
  referral: { create: vi.fn() },
  user: { update: vi.fn() },
  walletTransaction: { create: vi.fn(), update: vi.fn() },
};

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
}));

vi.mock('../config/env.js', () => ({
  env: {
    RAZORPAY_KEY_ID: 'test_key',
    RAZORPAY_KEY_SECRET: 'test_secret',
    RAZORPAY_ACCOUNT_NUMBER: '232323000000',
  },
}));

global.fetch = vi.fn();

// ─── Imports ──────────────────────────────────────────────────────────────────

import {
  getWalletBalance,
  getWalletSummary,
  generateReferralCode,
  applyReferralCode,
  getTransactions,
  processPendingWalletPayouts
} from '../modules/wallet/wallet.service.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';

describe('Wallet Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getWalletBalance', () => {
    it('returns user wallet balance', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ walletBalance: new Prisma.Decimal(150), referralCode: 'REF123' } as any);
      const res = await getWalletBalance('u1');
      expect(res.walletBalance.toNumber()).toBe(150);
    });

    it('throws AppError.notFound if user does not exist', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue(null);
      await expect(getWalletBalance('u1')).rejects.toSatisfy((err: any) => err instanceof AppError && err.statusCode === 404);
    });
  });

  describe('getWalletSummary', () => {
    it('returns balance and calculates referral earnings', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ walletBalance: new Prisma.Decimal(150), referralCode: 'REF123' } as any);
      vi.mocked(prisma.referral.findMany).mockResolvedValue([
        { rewardAmount: new Prisma.Decimal(100) },
        { rewardAmount: new Prisma.Decimal(100) }
      ] as any);

      const res = await getWalletSummary('u1');
      expect(res.totalReferrals).toBe(2);
      expect(res.referralEarnings).toBe(200);
      expect(res.walletBalance.toNumber()).toBe(150);
    });
  });

  describe('generateReferralCode', () => {
    it('generates a 6-char uppercase code and saves it', async () => {
      await generateReferralCode('u1');
      expect(prisma.user.update).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: 'u1' },
        data: { referralCode: expect.stringMatching(/^[A-Z0-9]{6}$/) }
      }));
    });
  });

  describe('applyReferralCode', () => {
    it('fails if code is invalid', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue(null);
      await expect(applyReferralCode('u1', 'BAD')).rejects.toSatisfy((err: any) => err instanceof AppError && err.statusCode === 400);
    });

    it('fails if user tries to use their own code', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u1' } as any);
      await expect(applyReferralCode('u1', 'MINE')).rejects.toSatisfy((err: any) => err instanceof AppError && err.statusCode === 400);
    });

    it('fails if user already used a code', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u2' } as any);
      vi.mocked(prisma.referral.findFirst).mockResolvedValue({ id: 'ref1' } as any);
      await expect(applyReferralCode('u1', 'OTHER')).rejects.toSatisfy((err: any) => err instanceof AppError && err.statusCode === 400);
    });

    it('creates referral and updates both balances in transaction', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u2' } as any); // Referrer
      vi.mocked(prisma.referral.findFirst).mockResolvedValue(null);
      
      prismaMockTx.user.update.mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(100) } as any);
      prismaMockTx.user.update.mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(100) } as any);

      const res = await applyReferralCode('u1', 'OTHER');
      expect(res.success).toBe(true);
      expect(res.rewardAmount).toBe(100);

      expect(prismaMockTx.referral.create).toHaveBeenCalled();
      expect(prismaMockTx.user.update).toHaveBeenCalledTimes(2);
      expect(prismaMockTx.walletTransaction.create).toHaveBeenCalledTimes(2);
    });
  });

  describe('getTransactions', () => {
    it('queries by workerId if provided', async () => {
      await getTransactions('u1', 'w1');
      expect(prisma.walletTransaction.findMany).toHaveBeenCalledWith({
        where: { workerId: 'w1' },
        orderBy: { createdAt: 'desc' }
      });
    });

    it('queries by userId if no workerId', async () => {
      await getTransactions('u1');
      expect(prisma.walletTransaction.findMany).toHaveBeenCalledWith({
        where: { userId: 'u1' },
        orderBy: { createdAt: 'desc' }
      });
    });
  });

  describe('processPendingWalletPayouts', () => {
    it('does nothing if no pending payouts', async () => {
      vi.mocked(prisma.walletTransaction.findMany).mockResolvedValue([]);
      await processPendingWalletPayouts();
      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('processes payout and updates to success', async () => {
      vi.mocked(prisma.walletTransaction.findMany).mockResolvedValue([
        { 
          id: 'tx1', amount: new Prisma.Decimal(-500), metadata: { upiId: 'test@upi' },
          user: { id: 'u1', name: 'Test User', phone: '9999999999' }
        } as any
      ]);

      (global.fetch as any).mockResolvedValue({
        ok: true,
        json: async () => ({ id: 'pout_123' })
      });

      await processPendingWalletPayouts();

      expect(global.fetch).toHaveBeenCalledWith('https://api.razorpay.com/v1/payouts', expect.any(Object));
      expect(prisma.walletTransaction.update).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: 'tx1' },
        data: expect.objectContaining({ type: 'PAYOUT_SUCCESS' })
      }));
    });

    it('handles payout failure by refunding wallet', async () => {
      vi.mocked(prisma.walletTransaction.findMany).mockResolvedValue([
        { 
          id: 'tx1', amount: new Prisma.Decimal(-500), metadata: { upiId: 'test@upi' },
          user: { id: 'u1', name: 'Test User', phone: '9999999999' }
        } as any
      ]);

      (global.fetch as any).mockResolvedValue({
        ok: false,
        json: async () => ({ error: { description: 'Insufficient balance' } })
      });

      prismaMockTx.walletTransaction.update.mockResolvedValue({ id: 'tx1', amount: new Prisma.Decimal(-500), userId: 'u1' } as any);
      prismaMockTx.user.update.mockResolvedValue({ walletBalance: new Prisma.Decimal(500) } as any);

      await processPendingWalletPayouts();

      expect(prismaMockTx.walletTransaction.update).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ type: 'PAYOUT_FAILED' })
      }));
      expect(prismaMockTx.user.update).toHaveBeenCalledWith({
        where: { id: 'u1' },
        data: { walletBalance: { increment: 500 } }
      });
      expect(prismaMockTx.walletTransaction.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ type: 'PAYOUT_REFUND', amount: 500 })
      }));
    });
  });
});
