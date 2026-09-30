import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn((cb) => cb(prismaMockTx)),
    user: { findUnique: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
    platformConfig: { findUnique: vi.fn() },
    workerProfile: { findUnique: vi.fn() },
    referral: { findMany: vi.fn(), findFirst: vi.fn(), create: vi.fn() },
    walletTransaction: { findMany: vi.fn(), create: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  },
}));

const prismaMockTx = {
  workerProfile: { findUnique: vi.fn() },
  referral: { create: vi.fn() },
  user: { update: vi.fn(), updateMany: vi.fn(), findUnique: vi.fn() },
  walletTransaction: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
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
  requestWorkerPayout,
  getTransactions,
  processPendingWalletPayouts
} from '../modules/wallet/wallet.service.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';

describe('Wallet Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue(null);
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
      expect(res.referralRewardAmount).toBe(100);
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
      prismaMockTx.user.updateMany.mockResolvedValue({ count: 1 } as any);
      
      prismaMockTx.user.update.mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(100) } as any);
      prismaMockTx.user.update.mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(100) } as any);

      const res = await applyReferralCode('u1', 'OTHER');
      expect(res.success).toBe(true);
      expect(res.rewardAmount).toBe(100);

      expect(prismaMockTx.referral.create).toHaveBeenCalled();
      expect(prismaMockTx.user.update).toHaveBeenCalledTimes(2);
      expect(prismaMockTx.walletTransaction.create).toHaveBeenCalledTimes(2);
    });

    it('uses the referral reward configured by the admin', async () => {
      vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue({ referralRewardAmount: new Prisma.Decimal(45) } as any);
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u2' } as any);
      vi.mocked(prisma.referral.findFirst).mockResolvedValue(null);
      prismaMockTx.user.updateMany.mockResolvedValue({ count: 1 } as any);
      prismaMockTx.user.update.mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(45) } as any);
      prismaMockTx.user.update.mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(45) } as any);

      const result = await applyReferralCode('u1', 'OTHER');

      expect(result.rewardAmount).toBe(45);
      expect(prismaMockTx.referral.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ rewardAmount: 45 })
      }));
    });

    it('rejects referrals when rewards are disabled', async () => {
      vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue({ referralsEnabled: false } as any);
      await expect(applyReferralCode('u1', 'OTHER')).rejects.toMatchObject({ statusCode: 400 });
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('does not issue a reward after the referrer reaches the configured cap', async () => {
      vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue({
        referralMaxSuccessfulPerReferrer: 2
      } as any);
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u2' } as any);
      vi.mocked(prisma.referral.findFirst).mockResolvedValue(null);
      prismaMockTx.user.updateMany.mockResolvedValue({ count: 0 } as any);

      await expect(applyReferralCode('u1', 'OTHER')).rejects.toMatchObject({
        statusCode: 400,
        message: 'Referral reward limit reached'
      });
      expect(prismaMockTx.referral.create).not.toHaveBeenCalled();
      expect(prismaMockTx.walletTransaction.create).not.toHaveBeenCalled();
    });
  });

  describe('requestWorkerPayout', () => {
    it('rejects values below the minimum and fractional paise before touching the wallet', async () => {
      await expect(requestWorkerPayout({ userId: 'u1', amount: 99.99 }))
        .rejects.toMatchObject({ statusCode: 400 });
      await expect(requestWorkerPayout({ userId: 'u1', amount: 100.001 }))
        .rejects.toMatchObject({ statusCode: 400 });
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('uses the minimum payout configured by the admin', async () => {
      vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue({ minimumWorkerPayout: new Prisma.Decimal(250) } as any);
      await expect(requestWorkerPayout({ userId: 'u1', amount: 200 }))
        .rejects.toMatchObject({ statusCode: 400, message: 'Minimum payout amount is 250' });
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('debts wallet and records a payout request inside a transaction', async () => {
      prismaMockTx.workerProfile.findUnique.mockResolvedValue({
        id: 'wp_1',
        upiId: 'worker@upi'
      } as any);
      prismaMockTx.user.updateMany.mockResolvedValue({ count: 1 } as any);
      prismaMockTx.user.findUnique.mockResolvedValue({ walletBalance: new Prisma.Decimal(350) } as any);
      prismaMockTx.walletTransaction.create.mockResolvedValue({ id: 'tx_payout_1' } as any);

      const result = await requestWorkerPayout({
        userId: 'u1',
        amount: 150,
        upiId: 'worker@upi'
      });

      expect(prismaMockTx.user.updateMany).toHaveBeenCalledWith({
        where: {
          id: 'u1',
          walletBalance: { gte: 150 }
        },
        data: {
          walletBalance: { decrement: 150 }
        }
      });
      expect(prismaMockTx.walletTransaction.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({
          userId: 'u1',
          workerId: 'wp_1',
          type: 'PAYOUT_PENDING',
          amount: -150
        })
      }));
      expect(result.newBalance).toBe(350);
      expect(result.upiId).toBe('worker@upi');
    });

    it('rejects a payout when the wallet balance is insufficient', async () => {
      prismaMockTx.workerProfile.findUnique.mockResolvedValue({
        id: 'wp_1',
        upiId: 'worker@upi'
      } as any);
      prismaMockTx.user.updateMany.mockResolvedValue({ count: 0 } as any);

      await expect(
        requestWorkerPayout({
          userId: 'u1',
          amount: 999,
          upiId: 'worker@upi'
        })
      ).rejects.toSatisfy((err: any) => err instanceof AppError && err.statusCode === 400);
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
          id: 'tx1', userId: 'u1', workerId: 'w1', amount: new Prisma.Decimal(-500), metadata: { upiId: 'test@upi' },
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
          id: 'tx1', userId: 'u1', workerId: 'w1', amount: new Prisma.Decimal(-500), metadata: { upiId: 'test@upi' },
          user: { id: 'u1', name: 'Test User', phone: '9999999999' },
          worker: { upiId: 'test@upi' }
        } as any
      ]);

      (global.fetch as any).mockResolvedValue({
        ok: false,
        status: 400,
        json: async () => ({ error: { description: 'Insufficient balance' } })
      });

      prismaMockTx.walletTransaction.updateMany.mockResolvedValue({ count: 1 });
      prismaMockTx.user.update.mockResolvedValue({ walletBalance: new Prisma.Decimal(500) } as any);

      await processPendingWalletPayouts();

      expect(prismaMockTx.walletTransaction.updateMany).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: 'tx1', type: 'PAYOUT_PENDING' },
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

    it('keeps uncertain provider outcomes pending without refunding', async () => {
      vi.mocked(prisma.walletTransaction.findMany).mockResolvedValue([
        {
          id: 'tx-timeout', userId: 'u1', workerId: 'w1', amount: new Prisma.Decimal(-500), metadata: { upiId: 'test@upi' },
          user: { id: 'u1', name: 'Test User', phone: '9999999999' },
          worker: { upiId: 'test@upi' }
        } as any
      ]);
      (global.fetch as any).mockRejectedValue(new Error('socket timeout'));

      await processPendingWalletPayouts();

      expect(prisma.walletTransaction.updateMany).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: 'tx-timeout', type: 'PAYOUT_PENDING' },
        data: { metadata: expect.objectContaining({ reconciliationRequired: true }) }
      }));
      expect(prismaMockTx.user.update).not.toHaveBeenCalled();
      expect(prismaMockTx.walletTransaction.create).not.toHaveBeenCalled();
    });

    it('keeps rate-limited provider outcomes pending for reconciliation', async () => {
      vi.mocked(prisma.walletTransaction.findMany).mockResolvedValue([
        {
          id: 'tx-rate-limited', userId: 'u1', workerId: 'w1', amount: new Prisma.Decimal(-500), metadata: {},
          user: { id: 'u1', name: 'Test User', phone: '9999999999' },
          worker: { upiId: 'test@upi' }
        } as any
      ]);
      (global.fetch as any).mockResolvedValue({
        ok: false,
        status: 429,
        json: async () => ({})
      });

      await processPendingWalletPayouts();

      expect(prisma.walletTransaction.updateMany).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: 'tx-rate-limited', type: 'PAYOUT_PENDING' },
        data: { metadata: expect.objectContaining({ reconciliationRequired: true }) }
      }));
      expect(prismaMockTx.user.update).not.toHaveBeenCalled();
    });
  });
});
