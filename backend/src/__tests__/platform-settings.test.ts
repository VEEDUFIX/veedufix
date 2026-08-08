import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/audit.js', () => ({
  writeAuditLog: vi.fn(),
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    platformConfig: { upsert: vi.fn() },
    invoiceSequence: { upsert: vi.fn() },
    commissions: { findMany: vi.fn(), findFirst: vi.fn(), findUnique: vi.fn(), create: vi.fn(), update: vi.fn(), delete: vi.fn() },
    city: { findMany: vi.fn(), findUnique: vi.fn() },
    adminAuditLog: { findMany: vi.fn() },
    $transaction: vi.fn((cb) => Array.isArray(cb) ? Promise.all(cb) : cb(prismaMockTx)),
  },
}));

const prismaMockTx = {
  platformConfig: { upsert: vi.fn() },
  invoiceSequence: { upsert: vi.fn() },
};

// ─── Imports ──────────────────────────────────────────────────────────────────

import {
  getPlatformSettings,
  savePlatformSettings,
  saveCommission,
  deleteCommission
} from '../modules/platform-settings/platform-settings.service.js';
import { prisma } from '../lib/prisma.js';
import { writeAuditLog } from '../lib/audit.js';

describe('Platform Settings Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getPlatformSettings', () => {
    it('returns platform config, invoice sequence, commissions, and cities', async () => {
      vi.mocked(prisma.platformConfig.upsert).mockResolvedValue({
        key: 'primary', gstin: 'GST123', legalBusinessName: 'Inc', registeredAddress: '123 St',
        createdAt: new Date(), updatedAt: new Date()
      });
      vi.mocked(prisma.invoiceSequence.upsert).mockResolvedValue({
        key: 'invoice', currentValue: 10,
        createdAt: new Date(), updatedAt: new Date()
      });
      vi.mocked(prisma.commissions.findMany).mockResolvedValue([
        {
          id: 'c1', cityId: null, rate: new Prisma.Decimal(20), fixedFee: new Prisma.Decimal(0),
          isActive: true, createdAt: new Date(), updatedAt: new Date()
        }
      ] as any);
      vi.mocked(prisma.city.findMany).mockResolvedValue([
        { id: 'city1', name: 'Chennai', slug: 'chennai', state: 'TN', isActive: true }
      ] as any);

      const res = await getPlatformSettings();
      expect(res.platformConfig.gstin).toBe('GST123');
      expect(res.invoiceSequence.currentValue).toBe(10);
      expect(res.commissions[0].rate).toBe(20);
      expect(res.cities[0].name).toBe('Chennai');
    });
  });

  describe('savePlatformSettings', () => {
    it('saves settings and logs audit', async () => {
      vi.mocked(prisma.platformConfig.upsert).mockResolvedValue({
        key: 'primary', gstin: 'GST123', legalBusinessName: 'Inc', registeredAddress: '123 St',
        createdAt: new Date(), updatedAt: new Date()
      });
      vi.mocked(prisma.invoiceSequence.upsert).mockResolvedValue({
        key: 'invoice', currentValue: 10,
        createdAt: new Date(), updatedAt: new Date()
      });
      vi.mocked(prisma.commissions.findMany).mockResolvedValue([]);
      vi.mocked(prisma.city.findMany).mockResolvedValue([]);

      const payload = {
        gstin: 'GST999',
        legalBusinessName: 'New Inc',
        invoiceSequenceCurrentValue: 100
      };

      await savePlatformSettings(payload);
      
      expect(writeAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'platform.settings_updated',
        metadata: {
          gstin: 'GST999',
          legalBusinessName: 'New Inc',
          registeredAddress: null,
          invoiceSequenceCurrentValue: 100
        }
      }));
    });
  });

  describe('saveCommission', () => {
    it('creates a new commission if not exists', async () => {
      vi.mocked(prisma.commissions.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.commissions.create).mockResolvedValue({
        id: 'c1', cityId: 'city1', rate: new Prisma.Decimal(15), fixedFee: new Prisma.Decimal(0),
        isActive: true, createdAt: new Date(), updatedAt: new Date()
      } as any);

      const res = await saveCommission(null, { cityId: 'city1', rate: 15, fixedFee: 0 });
      expect(prisma.commissions.create).toHaveBeenCalled();
      expect(res.commission.rate).toBe(15);
      expect(writeAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'commission.created'
      }));
    });
  });
});
