import { describe, it, expect, vi, beforeEach } from 'vitest';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    serviceArea: { findMany: vi.fn() },
  },
}));

// ─── Imports ──────────────────────────────────────────────────────────────────

import {
  findServiceableArea,
  assertServiceablePincode,
  getServiceAreaUnavailableMessage
} from '../modules/service-area/service-area.service.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';

describe('Service Area Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('findServiceableArea', () => {
    it('returns null for invalid pincode format', async () => {
      const res = await findServiceableArea({ pincode: 'abc' });
      expect(res).toBeNull();
      expect(prisma.serviceArea.findMany).not.toHaveBeenCalled();
    });

    it('returns null if no areas match', async () => {
      vi.mocked(prisma.serviceArea.findMany).mockResolvedValue([
        { pincode: '110001', city: { name: 'Delhi', slug: 'delhi' } }
      ] as any);

      const res = await findServiceableArea({ pincode: '600001' });
      expect(res).toBeNull();
    });

    it('matches exact pincode', async () => {
      vi.mocked(prisma.serviceArea.findMany).mockResolvedValue([
        { id: 'a1', name: 'Chennai Central', slug: 'chennai-central', cityId: 'c1', pincode: '600001', city: { name: 'Chennai', slug: 'chennai' } }
      ] as any);

      const res = await findServiceableArea({ pincode: '600001' });
      expect(res!.name).toBe('Chennai Central');
    });

    it('matches pincode within range', async () => {
      vi.mocked(prisma.serviceArea.findMany).mockResolvedValue([
        { 
          id: 'a1', name: 'Chennai North', slug: 'chennai-north', cityId: 'c1', 
          pincodeRangeStart: '600000', pincodeRangeEnd: '600010',
          city: { name: 'Chennai', slug: 'chennai' }
        }
      ] as any);

      const res = await findServiceableArea({ pincode: '600005' });
      expect(res!.name).toBe('Chennai North');
    });

    it('filters by city name', async () => {
      vi.mocked(prisma.serviceArea.findMany).mockResolvedValue([
        { pincode: '600001', city: { name: 'Mumbai', slug: 'mumbai' } }
      ] as any);

      const res = await findServiceableArea({ pincode: '600001', city: 'Chennai' });
      expect(res).toBeNull(); // Pincode matches, but city name doesn't
    });
  });

  describe('assertServiceablePincode', () => {
    it('returns area if found', async () => {
      vi.mocked(prisma.serviceArea.findMany).mockResolvedValue([
        { id: 'a1', name: 'Chennai Central', slug: 'chennai-central', cityId: 'c1', pincode: '600001', city: { name: 'Chennai', slug: 'chennai' } }
      ] as any);

      const res = await assertServiceablePincode({ pincode: '600001' });
      expect(res.name).toBe('Chennai Central');
    });

    it('throws AppError.badRequest if not found', async () => {
      vi.mocked(prisma.serviceArea.findMany).mockResolvedValue([]);
      
      await expect(assertServiceablePincode({ pincode: '600001' })).rejects.toSatisfy(
        (err: any) => err instanceof AppError && err.statusCode === 400 && err.message === getServiceAreaUnavailableMessage()
      );
    });
  });
});
