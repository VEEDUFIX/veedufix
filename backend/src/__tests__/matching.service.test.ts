import { describe, it, expect, vi, beforeEach } from 'vitest';
import { BookingStatus, VerificationStatus } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../config/env.js', () => ({
  env: {
    PORT: 4000,
    NODE_ENV: 'test',
    JWT_SECRET: 'test-secret',
    JWT_EXPIRES_IN: '1h',
    REDIS_URL: 'redis://localhost:6379',
    RAZORPAY_KEY_ID: 'test',
    RAZORPAY_KEY_SECRET: 'test',
    RAZORPAY_WEBHOOK_SECRET: 'test',
    RAZORPAY_ACCOUNT_NUMBER: 'test1234',
    ADMIN_EMAIL: 'test@example.com',
    ADMIN_PASSWORD: 'test'
  }
}));

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() }
}));
vi.mock('../lib/realtime.js', () => ({
  publishNotificationEvent: vi.fn(),
  publishTrackingEvent: vi.fn(),
}));
vi.mock('../lib/booking-timeline.js', () => ({
  recordBookingTimelineEvent: vi.fn(),
}));
vi.mock('../modules/device-token/device-token.service.js', () => ({
  getTokensForUser: vi.fn().mockResolvedValue(['token1']),
}));
vi.mock('../lib/fcm.js', () => ({
  sendMulticastPush: vi.fn(),
}));
vi.mock('../lib/maps.js', () => ({
  getTravelTimeMinutes: vi.fn().mockResolvedValue(15),
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: vi.fn(), findMany: vi.fn(), update: vi.fn() },
    workerProfile: { findMany: vi.fn(), findUnique: vi.fn() },
    workerAvailability: { findMany: vi.fn() },
    dispatchOffer: { create: vi.fn(), findMany: vi.fn(), findFirst: vi.fn(), updateMany: vi.fn(), findUnique: vi.fn() },
    jobExecution: { upsert: vi.fn() },
    user: { findMany: vi.fn() },
  },
}));

// ─── Imports ──────────────────────────────────────────────────────────────────

import {
  findAvailableWorkers,
  assignJobWithFallback,
  acceptJobOffer,
  rejectJobOffer,
  DispatchConflictError,
  OfferAuthorizationError
} from '../modules/matching/matching.service.js';
import { prisma } from '../lib/prisma.js';

describe('Matching Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('findAvailableWorkers', () => {
    it('returns ranked workers based on distance and score', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1',
        address: { latitude: 12.9716, longitude: 77.5946 }, // Bangalore
        services: [{ service: { categoryId: 'c1' } }],
        city: { name: 'Bengaluru' }
      } as any);

      vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([
        {
          id: 'w1', userId: 'u1', averageRating: 5,
          latitude: 12.9720, longitude: 77.5950, // very close
          cityRelation: { name: 'Bengaluru' }
        },
        {
          id: 'w2', userId: 'u2', averageRating: 4,
          latitude: 13.0827, longitude: 80.2707, // far away (Chennai)
          cityRelation: { name: 'Chennai' }
        }
      ] as any);

      vi.mocked(prisma.booking.findMany).mockResolvedValue([]); // no active jobs or last completions

      const res = await findAvailableWorkers('b1');
      expect(res.length).toBeGreaterThan(0);
      expect(res[0].workerProfileId).toBe('w1');
    });
  });

  describe('assignJobWithFallback', () => {
    it('throws DispatchConflictError if booking is not in an accepted state', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1', status: BookingStatus.PENDING,
        address: { latitude: 12.9716, longitude: 77.5946 },
        services: [{ service: { categoryId: 'c1' } }],
        city: { name: 'Bengaluru' }
      } as any);

      await expect(assignJobWithFallback('b1')).rejects.toThrow(DispatchConflictError);
    });

    it('returns failed status if no candidates found', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1', status: BookingStatus.ACCEPTED,
        address: { latitude: 12.9716, longitude: 77.5946 },
        services: [{ service: { categoryId: 'c1' } }],
        city: { name: 'Bengaluru' }
      } as any);
      vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([]);
      vi.mocked(prisma.booking.findMany).mockResolvedValue([]);
      vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: 'admin1' }] as any);

      const res = await assignJobWithFallback('b1');
      expect(res.status).toBe('failed');
      expect(prisma.booking.update).toHaveBeenCalledWith(expect.objectContaining({
        where: { id: 'b1' },
        data: { status: BookingStatus.DISPATCH_FAILED }
      }));
    });
  });

  describe('acceptJobOffer', () => {
    it('throws OfferAuthorizationError if user is not the worker', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1',
        address: { latitude: 12.9716, longitude: 77.5946 },
        services: [{ service: { categoryId: 'c1' } }],
        city: { name: 'Bengaluru' }
      } as any);
      vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue(null); // not a worker

      await expect(acceptJobOffer('b1', 'u1')).rejects.toThrow(OfferAuthorizationError);
    });
  });
});
