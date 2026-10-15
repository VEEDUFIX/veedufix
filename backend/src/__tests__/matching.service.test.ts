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
  findAvailableWorkersForSchedule,
  assignJobWithFallback,
  acceptJobOffer,
  rejectJobOffer,
  DispatchConflictError,
  OfferAuthorizationError,
  previewCustomerScheduleSlots,
  assertAssignedPartnerAvailableForRemedy
} from '../modules/matching/matching.service.js';
import { prisma } from '../lib/prisma.js';

describe('Matching Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const bookingCoordinates = { latitude: 12.9716, longitude: 77.5946 };

  function workerAtDistance(
    id: string,
    distanceKm: number,
    serviceRadiusKm: number | null = 10
  ) {
    const longitudeDelta = distanceKm /
      (111.32 * Math.cos((bookingCoordinates.latitude * Math.PI) / 180));
    return {
      id,
      userId: `user-${id}`,
      averageRating: 4.5,
      isAvailable: true,
      isOnline: true,
      onboardingStatus: 'approved',
      verificationStatus: VerificationStatus.VERIFIED,
      serviceRadiusKm,
      latitude: bookingCoordinates.latitude,
      longitude: bookingCoordinates.longitude + longitudeDelta,
      cityRelation: { name: 'Bengaluru' },
      skills: [{ categoryId: 'category-1', verifiedByAdmin: true }],
      workerServices: [{ serviceId: 'service-1', isAvailable: true }]
    };
  }

  function mockBookingAndCandidates(
    candidates: ReturnType<typeof workerAtDistance>[],
    activeBookings: Array<{ workerId: string; jobExecution: { status: string } | null }> = []
  ) {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      id: 'booking-1',
      code: 'B-1',
      cityId: 'bengaluru',
      address: { ...bookingCoordinates, pincode: '560001' },
      services: [{ service: { id: 'service-1', categoryId: 'category-1' } }],
      city: { name: 'Bengaluru' }
    } as any);
    vi.mocked(prisma.workerProfile.findMany).mockResolvedValue(candidates as any);
    vi.mocked(prisma.workerAvailability.findMany).mockResolvedValue(
      candidates.map((worker) => ({
        workerId: worker.id,
        dayOfWeek: 1,
        startTime: '00:00',
        endTime: '23:59'
      })) as any
    );
    vi.mocked(prisma.booking.findMany).mockImplementation(async (args: any) => {
      if (args?.where?.status === BookingStatus.COMPLETED || args?.where?.bookingType === 'scheduled') {
        return [] as any;
      }
      return activeBookings as any;
    });
  }

  describe('Partner-specific travel radius', () => {
    it('keeps a Partner whose distance is within their configured radius', async () => {
      mockBookingAndCandidates([workerAtDistance('within', 5, 10)]);

      const candidates = await findAvailableWorkers('booking-1');

      expect(candidates.map((candidate) => candidate.workerProfileId)).toEqual(['within']);
    });

    it('rejects a Partner whose distance is beyond their configured radius', async () => {
      mockBookingAndCandidates([workerAtDistance('outside', 8, 5)]);

      const candidates = await findAvailableWorkers('booking-1');

      expect(candidates).toEqual([]);
    });

    it('evaluates each Partner against their own radius instead of a shared radius band', async () => {
      mockBookingAndCandidates([
        workerAtDistance('large-radius', 15, 20),
        workerAtDistance('small-radius', 15, 10)
      ]);

      const candidates = await findAvailableWorkers('booking-1');

      expect(candidates.map((candidate) => candidate.workerProfileId)).toEqual(['large-radius']);
    });

    it('rejects a service-area match when the Partner radius is too small', async () => {
      mockBookingAndCandidates([workerAtDistance('area-match', 5, 2)]);

      const candidates = await findAvailableWorkers('booking-1');
      const query = vi.mocked(prisma.workerProfile.findMany).mock.calls[0]?.[0];

      expect(candidates).toEqual([]);
      expect(query?.where?.serviceAreaAssignments).toMatchObject({
        some: {
          serviceArea: {
            isActive: true,
            city: { isActive: true, id: 'bengaluru' },
            OR: expect.arrayContaining([
              { pincode: '560001' },
              { assignedPincodes: { some: { pincode: '560001' } } }
            ])
          }
        }
      });
    });

    it('does not treat a missing radius as unlimited and uses the safe 10 km default', async () => {
      mockBookingAndCandidates([workerAtDistance('default-radius', 11, null)]);

      const candidates = await findAvailableWorkers('booking-1');

      expect(candidates).toEqual([]);
    });

    it('accepts a Partner within the safe default radius when no radius is configured', async () => {
      mockBookingAndCandidates([workerAtDistance('default-radius-within', 9, null)]);

      const candidates = await findAvailableWorkers('booking-1');

      expect(candidates.map((candidate) => candidate.workerProfileId)).toEqual([
        'default-radius-within'
      ]);
    });

    it('rejects a radius-qualified Partner when the service qualification query does not match', async () => {
      mockBookingAndCandidates([]);

      const candidates = await findAvailableWorkers('booking-1');
      const query = vi.mocked(prisma.workerProfile.findMany).mock.calls[0]?.[0];

      expect(candidates).toEqual([]);
      expect(query?.where?.AND).toEqual([
        { skills: { some: { categoryId: 'category-1', verifiedByAdmin: true } } },
        { workerServices: { some: { serviceId: 'service-1', isAvailable: true } } }
      ]);
    });

    it('rejects a radius-qualified Partner when the database eligibility query marks them offline', async () => {
      mockBookingAndCandidates([]);

      const candidates = await findAvailableWorkers('booking-1');
      const query = vi.mocked(prisma.workerProfile.findMany).mock.calls[0]?.[0];

      expect(candidates).toEqual([]);
      expect(query?.where).toMatchObject({ isAvailable: true, isOnline: true });
    });

    it('rejects a radius-qualified Partner with an active conflicting job', async () => {
      mockBookingAndCandidates([workerAtDistance('busy', 5, 10)], [
        { workerId: 'busy', jobExecution: { status: 'in_progress' } }
      ]);

      const candidates = await findAvailableWorkers('booking-1');

      expect(candidates).toEqual([]);
    });
  });

  describe('previewCustomerScheduleSlots', () => {
    it('returns only future slots within worker hours and outside existing bookings', async () => {
      vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([
        {
          id: 'w1',
          latitude: 13.0828,
          longitude: 80.2708,
          serviceRadiusKm: 20,
          isAvailable: false,
          isOnline: false,
        }
      ] as any);
      vi.mocked(prisma.workerAvailability.findMany).mockResolvedValue(
        [0, 1, 2, 3, 4, 5, 6].map((dayOfWeek) => ({
          workerId: 'w1',
          dayOfWeek,
          startTime: '09:00',
          endTime: '18:00'
        })) as any
      );
      vi.mocked(prisma.booking.findMany).mockResolvedValue([
        { workerId: 'w1', scheduledFor: new Date('2099-01-05T03:30:00.000Z') }
      ] as any);

      const slots = await previewCustomerScheduleSlots({
        cityId: 'chennai',
        services: [{ serviceId: 'service-1', categoryId: 'category-1' }],
        pincode: '600001',
        latitude: 13.0827,
        longitude: 80.2707,
        cityName: 'Chennai',
        startDate: '2099-01-05',
        days: 1
      });

      expect(slots).toHaveLength(4);
      expect(slots.map((slot) => new Date(slot.scheduledFor).toISOString())).not.toContain(
        '2099-01-05T03:30:00.000Z'
      );
      expect(prisma.workerAvailability.findMany).toHaveBeenCalledTimes(1);
      expect(prisma.booking.findMany).toHaveBeenCalledTimes(1);
      const candidateQuery = vi.mocked(prisma.workerProfile.findMany).mock.calls[0]?.[0];
      expect(candidateQuery?.where).not.toHaveProperty('isAvailable');
      expect(candidateQuery?.where).not.toHaveProperty('isOnline');
    });
  });

  it('includes offline Partners in scheduled dispatch when their future hours qualify', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      id: 'scheduled-1',
      code: 'S-1',
      cityId: 'bengaluru',
      bookingType: 'scheduled',
      scheduledFor: new Date('2099-01-05T09:00:00.000Z'),
      address: { ...bookingCoordinates, pincode: '560001' },
      services: [{ service: { id: 'service-1', categoryId: 'category-1' } }],
      city: { name: 'Bengaluru' }
    } as any);
    vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([] as any);

    await findAvailableWorkersForSchedule('scheduled-1');

    const candidateQuery = vi.mocked(prisma.workerProfile.findMany).mock.calls[0]?.[0];
    expect(candidateQuery?.where).not.toHaveProperty('isAvailable');
    expect(candidateQuery?.where).not.toHaveProperty('isOnline');
  });

  it('does not require instant availability for a scheduled corrective visit', async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({
      id: 'completed-1',
      status: BookingStatus.COMPLETED,
      workerId: 'worker-1',
      cityId: 'bengaluru',
      address: { ...bookingCoordinates, pincode: '560001' },
      services: [{ service: { id: 'service-1', categoryId: 'category-1' } }],
      city: { name: 'Bengaluru' }
    } as any);
    vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([] as any);

    await expect(
      assertAssignedPartnerAvailableForRemedy('completed-1', new Date('2099-01-05T09:00:00.000Z'))
    ).rejects.toThrow('not eligible or available');

    const candidateQuery = vi.mocked(prisma.workerProfile.findMany).mock.calls[0]?.[0];
    expect(candidateQuery?.where).not.toHaveProperty('isAvailable');
    expect(candidateQuery?.where).not.toHaveProperty('isOnline');
  });

  describe('findAvailableWorkers', () => {
    it('returns ranked workers based on distance and score', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1',
        cityId: 'bengaluru',
        address: { latitude: 12.9716, longitude: 77.5946, pincode: '560001' }, // Bangalore
        services: [{ service: { id: 's1', categoryId: 'c1' } }],
        city: { name: 'Bengaluru' }
      } as any);

      vi.mocked(prisma.workerProfile.findMany).mockResolvedValue([
        {
          id: 'w1', userId: 'u1', averageRating: 5,
          isAvailable: true, isOnline: true, onboardingStatus: 'approved',
          verificationStatus: VerificationStatus.VERIFIED, serviceRadiusKm: 20,
          latitude: 12.9720, longitude: 77.5950, // very close
          cityRelation: { name: 'Bengaluru' }
        },
        {
          id: 'w2', userId: 'u2', averageRating: 4,
          isAvailable: true, isOnline: true, onboardingStatus: 'approved',
          verificationStatus: VerificationStatus.VERIFIED, serviceRadiusKm: 20,
          latitude: 13.0827, longitude: 80.2707, // far away (Chennai)
          cityRelation: { name: 'Chennai' }
        }
      ] as any);

      vi.mocked(prisma.booking.findMany).mockResolvedValue([]); // no active jobs or last completions
      vi.mocked(prisma.workerAvailability.findMany).mockResolvedValue([
        { workerId: 'w1', startTime: '00:00', endTime: '23:59' },
      ] as any);

      const res = await findAvailableWorkers('b1');
      expect(res.length).toBeGreaterThan(0);
      expect(res[0].workerProfileId).toBe('w1');
    });

    it('ranks a slightly farther highly rated Partner ahead of a nearer low-rated Partner', async () => {
      mockBookingAndCandidates([
        { ...workerAtDistance('near-low-rating', 4, 10), averageRating: 2 },
        { ...workerAtDistance('far-high-rating', 5, 10), averageRating: 5 }
      ]);

      const candidates = await findAvailableWorkers('booking-1');

      expect(candidates.map((candidate) => candidate.workerProfileId)).toEqual([
        'far-high-rating',
        'near-low-rating'
      ]);
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
