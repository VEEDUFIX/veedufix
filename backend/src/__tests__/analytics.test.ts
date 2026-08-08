import { describe, it, expect, vi, beforeEach } from 'vitest';
import { format, subDays } from 'date-fns';

// ─── Mocks ────────────────────────────────────────────────────────────────────
vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findMany: vi.fn(), count: vi.fn() },
    workerProfile: { findMany: vi.fn() },
  }
}));

// ─── Imports ──────────────────────────────────────────────────────────────────
import { getAnalyticsTrends } from '../modules/analytics/analytics.service.js';
import { prisma } from '../lib/prisma.js';

describe('Analytics Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getAnalyticsTrends', () => {
    it('aggregates trends and insights correctly', async () => {
      const today = new Date();
      const todayStr = format(today, 'yyyy-MM-dd');
      const yesterday = subDays(today, 1);
      const yesterdayStr = format(yesterday, 'yyyy-MM-dd');

      vi.mocked(prisma.booking.findMany).mockResolvedValue([
        {
          totalAmount: 100,
          updatedAt: today,
          city: { name: 'Chennai' },
          services: [{ service: { category: { name: 'Plumbing' } } }],
          payout: { commissionAmount: 20 }
        },
        {
          totalAmount: 150,
          updatedAt: yesterday,
          city: { name: 'Chennai' },
          services: [{ service: { category: { name: 'Electrical' } } }],
          payout: { commissionAmount: 30 }
        },
        {
          totalAmount: 50,
          updatedAt: today,
          city: { name: 'Bangalore' },
          services: [{ service: { category: { name: 'Plumbing' } } }],
          payout: { commissionAmount: 10 }
        }
      ] as any);

      vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([
        { createdAt: today },
        { createdAt: yesterday }
      ] as any);

      vi.mocked(prisma.booking.count).mockResolvedValue(5);

      const res = await getAnalyticsTrends(7);
      
      expect(res.activeBookings).toBe(5);
      
      const todayTrend = res.trends.find(t => t.date === todayStr);
      expect(todayTrend?.bookings).toBe(2);
      expect(todayTrend?.revenue).toBe(150);
      expect(todayTrend?.commission).toBe(30);
      expect(todayTrend?.newWorkers).toBe(1);

      const yesterdayTrend = res.trends.find(t => t.date === yesterdayStr);
      expect(yesterdayTrend?.bookings).toBe(1);
      expect(yesterdayTrend?.revenue).toBe(150);

      const chennaiCity = res.insights.byCity.find(c => c.label === 'Chennai');
      expect(chennaiCity?.bookings).toBe(2);
      expect(chennaiCity?.revenue).toBe(250);

      const plumbingCategory = res.insights.byCategory.find(c => c.label === 'Plumbing');
      expect(plumbingCategory?.bookings).toBe(2);
      expect(plumbingCategory?.revenue).toBe(150);
    });

    it('handles empty results', async () => {
      vi.mocked(prisma.booking.findMany).mockResolvedValue([]);
      vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([]);
      vi.mocked(prisma.booking.count).mockResolvedValue(0);

      const res = await getAnalyticsTrends(7);
      expect(res.activeBookings).toBe(0);
      expect(res.insights.byCity.length).toBe(0);
      expect(res.insights.byCategory.length).toBe(0);
      expect(res.trends.length).toBe(7);
    });
  });
});
