import { describe, it, expect, vi, beforeEach } from 'vitest';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    workerProfile: { count: vi.fn(), findMany: vi.fn() },
    $transaction: vi.fn((cb) => Promise.all(cb)),
  },
}));

// ─── Imports ──────────────────────────────────────────────────────────────────

import { listEligibleWorkers } from '../modules/worker-pool/worker-pool.service.js';
import { prisma } from '../lib/prisma.js';

describe('Worker Pool Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('listEligibleWorkers', () => {
    it('returns a paginated list of eligible workers', async () => {
      vi.mocked(prisma.workerProfile.count).mockResolvedValue(1);
      vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([{
        id: 'w1', fullName: 'John Doe',
        user: { name: 'John Doe' },
        skills: [{ categoryId: 'c1', category: { id: 'c1', name: 'Plumbing' } }]
      }] as any);

      const res = await listEligibleWorkers({ page: 1, limit: 10 });
      expect(res.total).toBe(1);
      expect(res.items[0].fullName).toBe('John Doe');
      expect(res.items[0].skills[0].category.name).toBe('Plumbing');
    });

    it('filters by cityId and categoryId', async () => {
      vi.mocked(prisma.workerProfile.count).mockResolvedValue(1);
      vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([{
        id: 'w1', fullName: 'John Doe',
        user: { name: 'John Doe' },
        skills: []
      }] as any);

      await listEligibleWorkers({ cityId: 'city1', categoryId: 'c1', onlyAvailable: true });
      
      expect(prisma.workerProfile.count).toHaveBeenCalledWith(expect.objectContaining({
        where: expect.objectContaining({
          cityId: 'city1',
          isAvailable: true,
          skills: { some: { categoryId: 'c1' } }
        })
      }));
    });
  });
});
