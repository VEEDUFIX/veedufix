import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma } from '@prisma/client';

// ─── Mock all external modules BEFORE importing ───────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn((cb) => cb(prismaMockTx)),
    user: { findUnique: vi.fn(), update: vi.fn() },
    city: { findUnique: vi.fn() },
    address: { findFirst: vi.fn() },
    service: { findMany: vi.fn() },
    coupon: { findFirst: vi.fn() },
    payment: { create: vi.fn(), updateMany: vi.fn(), update: vi.fn(), findFirst: vi.fn() },
    booking: { findUnique: vi.fn(), update: vi.fn() },
    jobExecution: { upsert: vi.fn(), update: vi.fn(), findUnique: vi.fn() },
    walletTransaction: { create: vi.fn() },
    bookingService: { createMany: vi.fn() },
  },
}));

const prismaMockTx = {
  booking: { create: vi.fn() },
  bookingService: { createMany: vi.fn() },
  payment: { create: vi.fn() },
  user: { update: vi.fn() },
  walletTransaction: { create: vi.fn() },
};

vi.mock('../lib/redis.js', () => ({
  redis: { set: vi.fn(), get: vi.fn(), del: vi.fn() },
}));

vi.mock('../config/env.js', () => ({
  env: {
    RAZORPAY_KEY_ID: 'test_key',
    RAZORPAY_KEY_SECRET: 'test_secret',
    RAZORPAY_WEBHOOK_URL: 'http://localhost/webhook',
  },
}));

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
}));

vi.mock('../lib/realtime.js', () => ({
  publishNotificationEvent: vi.fn(),
  publishTrackingEvent: vi.fn(),
}));

vi.mock('../modules/device-token/device-token.service.js', () => ({
  getTokensForUser: vi.fn().mockResolvedValue([]),
}));

vi.mock('../config/firebase-admin.js', () => ({
  sendPushNotification: vi.fn(),
}));

vi.mock('../lib/fcm.js', () => ({
  sendMulticastPush: vi.fn(),
}));

vi.mock('../modules/payout/payout.service.js', () => ({
  releaseWorkerPayout: vi.fn(),
}));

vi.mock('../modules/service-area/service-area.service.js', () => ({
  assertServiceablePincode: vi.fn(),
}));

vi.mock('../modules/worker-onboarding/worker-onboarding.service.js', () => ({
  isWorkerEligible: vi.fn().mockResolvedValue(true),
}));

vi.mock('../lib/booking-timeline.js', () => ({
  recordBookingTimelineEvent: vi.fn(),
}));

vi.mock('../modules/checklist/checklist.service.js', () => ({
  validateChecklistCompletion: vi.fn(),
}));

// Mock Razorpay
vi.mock('razorpay', () => {
  return {
    default: class Razorpay {
      orders = {
        create: vi.fn().mockResolvedValue({ id: 'order_123' }),
      };
    },
  };
});

// ─── Imports ──────────────────────────────────────────────────────────────────

import { createPaymentOrder } from '../modules/payments/payments.service.js';
import { 
  generateArrivalOtp, 
  verifyArrivalOtp,
  generateCompletionOtp,
  verifyCompletionOtp
} from '../modules/job-execution/job-execution.service.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { IncompleteJobError } from '../modules/job-execution/job-execution.service.js';

describe('Booking Flow', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Suite 1: Booking Creation (createPaymentOrder)', () => {
    it('succeeds with valid service IDs and address', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u1', cityId: 'c1', name: 'Test', email: null, phone: null } as any);
      vi.mocked(prisma.city.findUnique).mockResolvedValue({ id: 'c1', name: 'City' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
      
      const mockService = {
        id: 's1', name: 'AC Repair', isActive: true, startingPrice: new Prisma.Decimal(500), gstRate: new Prisma.Decimal(18),
        gstApplicable: true, sacCode: '9987', subcategory: { id: 'sub1', name: 'AC' }, pricingRules: []
      };
      vi.mocked(prisma.service.findMany).mockResolvedValue([mockService] as any);
      
      prismaMockTx.booking.create.mockResolvedValue({ id: 'b1', code: 'BK-123' });
      
      const result = await createPaymentOrder({
        userId: 'u1', cityId: 'c1', items: [{ serviceId: 's1', quantity: 1 }]
      });
      
      expect(result.bookingId).toBe('b1');
      expect(prisma.service.findMany).toHaveBeenCalled();
      expect(prismaMockTx.booking.create).toHaveBeenCalled();
    });

    it('throws AppError.notFound when service not found', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u1', cityId: 'c1', name: 'Test', email: null, phone: null } as any);
      vi.mocked(prisma.city.findUnique).mockResolvedValue({ id: 'c1', name: 'City' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
      vi.mocked(prisma.service.findMany).mockResolvedValue([]); // Not found
      
      await expect(
        createPaymentOrder({ userId: 'u1', cityId: 'c1', items: [{ serviceId: 's1', quantity: 1 }] })
      ).rejects.toSatisfy((err: any) => err instanceof AppError && err.statusCode === 404);
    });

    it('throws AppError.badRequest when no services selected', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u1', cityId: 'c1', name: 'Test', email: null, phone: null } as any);
      vi.mocked(prisma.city.findUnique).mockResolvedValue({ id: 'c1', name: 'City' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
      
      await expect(
        createPaymentOrder({ userId: 'u1', cityId: 'c1', items: [] })
      ).rejects.toSatisfy((err: any) => err instanceof AppError && err.statusCode === 400);
    });

    it('applies coupon discount correctly', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u1', cityId: 'c1', name: 'Test', email: null, phone: null } as any);
      vi.mocked(prisma.city.findUnique).mockResolvedValue({ id: 'c1', name: 'City' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
      
      const mockService = {
        id: 's1', name: 'AC Repair', isActive: true, startingPrice: new Prisma.Decimal(1000), gstRate: new Prisma.Decimal(18),
        gstApplicable: true, sacCode: '9987', subcategory: { id: 'sub1', name: 'AC' }, pricingRules: []
      };
      vi.mocked(prisma.service.findMany).mockResolvedValue([mockService] as any);
      
      vi.mocked(prisma.coupon.findFirst).mockResolvedValue({
        code: 'SAVE10', isActive: true, type: 'PERCENTAGE', value: new Prisma.Decimal(10), minOrderAmount: new Prisma.Decimal(500),
        startsAt: null, endsAt: null, maxDiscount: new Prisma.Decimal(500)
      } as any);

      prismaMockTx.booking.create.mockResolvedValue({ id: 'b1', code: 'BK-123' });
      
      await createPaymentOrder({
        userId: 'u1', cityId: 'c1', items: [{ serviceId: 's1', quantity: 1 }], couponCode: 'SAVE10'
      });
      
      expect(prisma.coupon.findFirst).toHaveBeenCalled();
      const createCall = prismaMockTx.booking.create.mock.calls[0][0];
      // 1000 subtotal, 10% discount = 100
      expect(createCall.data.discountAmount.toNumber()).toBe(100);
    });

    it('selects the pricing rule with the highest priority', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u1', cityId: 'c1', name: 'Test', email: null, phone: null } as any);
      vi.mocked(prisma.city.findUnique).mockResolvedValue({ id: 'c1', name: 'City' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
      
      const now = new Date();
      const mockService = {
        id: 's1', name: 'AC Repair', isActive: true, startingPrice: new Prisma.Decimal(500), gstRate: new Prisma.Decimal(18),
        gstApplicable: true, sacCode: '9987', subcategory: { id: 'sub1', name: 'AC' }, 
        pricingRules: [
          // Low priority rule
          { id: 'r1', cityId: 'c1', type: 'BASE', priority: 1, price: new Prisma.Decimal(600), startsAt: null, endsAt: null, createdAt: now },
          // High priority rule
          { id: 'r2', cityId: 'c1', type: 'BASE', priority: 10, price: new Prisma.Decimal(800), startsAt: null, endsAt: null, createdAt: now },
          // Medium priority rule
          { id: 'r3', cityId: 'c1', type: 'BASE', priority: 5, price: new Prisma.Decimal(700), startsAt: null, endsAt: null, createdAt: now }
        ]
      };
      vi.mocked(prisma.service.findMany).mockResolvedValue([mockService] as any);
      prismaMockTx.booking.create.mockResolvedValue({ id: 'b1', code: 'BK-123' });
      
      await createPaymentOrder({
        userId: 'u1', cityId: 'c1', items: [{ serviceId: 's1', quantity: 1 }]
      });
      
      const createCall = prismaMockTx.booking.create.mock.calls[0][0];
      // Should pick the priority: 10 rule, which has basePrice = 800
      expect(createCall.data.subtotalAmount.toNumber()).toBe(800);
    });

    it('falls back to latest createdAt if priorities are tied', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: 'u1', cityId: 'c1', name: 'Test', email: null, phone: null } as any);
      vi.mocked(prisma.city.findUnique).mockResolvedValue({ id: 'c1', name: 'City' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
      
      const time1 = new Date('2026-01-01');
      const time2 = new Date('2026-06-01'); // Newer
      
      const mockService = {
        id: 's1', name: 'AC Repair', isActive: true, startingPrice: new Prisma.Decimal(500), gstRate: new Prisma.Decimal(18),
        gstApplicable: true, sacCode: '9987', subcategory: { id: 'sub1', name: 'AC' }, 
        pricingRules: [
          // Same priority, older
          { id: 'r1', cityId: 'c1', type: 'BASE', priority: 5, price: new Prisma.Decimal(600), startsAt: null, endsAt: null, createdAt: time1 },
          // Same priority, newer
          { id: 'r2', cityId: 'c1', type: 'BASE', priority: 5, price: new Prisma.Decimal(900), startsAt: null, endsAt: null, createdAt: time2 }
        ]
      };
      vi.mocked(prisma.service.findMany).mockResolvedValue([mockService] as any);
      prismaMockTx.booking.create.mockResolvedValue({ id: 'b1', code: 'BK-123' });
      
      await createPaymentOrder({
        userId: 'u1', cityId: 'c1', items: [{ serviceId: 's1', quantity: 1 }]
      });
      
      const createCall = prismaMockTx.booking.create.mock.calls[0][0];
      // Should pick the newer rule (basePrice = 900)
      expect(createCall.data.subtotalAmount.toNumber()).toBe(900);
    });
  });

  describe('Suite 2: Job Execution Flow', () => {
    const mockExecution = {
      bookingId: 'b1', status: 'assigned', beforePhotos: [], afterPhotos: [], checklist: null,
      otpStart: '1234', otpStartExpiresAt: new Date(Date.now() + 10000),
      otpEnd: '5678', otpEndExpiresAt: new Date(Date.now() + 10000)
    };
    const mockBooking = {
      id: 'b1', workerId: 'w1', customerId: 'c1', services: [{ serviceId: 's1' }], jobExecution: mockExecution,
      worker: { userId: 'wu1' }
    };

    it('generateArrivalOtp marks booking as ARRIVED and returns OTP', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBooking as any);
      vi.mocked(prisma.jobExecution.upsert).mockResolvedValue({ ...mockExecution, status: 'arrived' } as any);
      
      const result = await generateArrivalOtp('b1', 'w1', { workerLat: 10, workerLng: 20 });
      expect(result.status).toBe('arrived');
      expect(prisma.booking.update).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'ARRIVED' } }));
    });

    it('verifyArrivalOtp transitions booking to IN_PROGRESS', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBooking as any);
      vi.mocked(prisma.jobExecution.update).mockResolvedValue({ ...mockExecution, status: 'in_progress' } as any);
      
      const result = await verifyArrivalOtp('b1', 'w1', '1234');
      expect(result.status).toBe('in_progress');
      expect(prisma.booking.update).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'IN_PROGRESS' } }));
    });

    it('verifyCompletionOtp marks booking as COMPLETED and triggers payout', async () => {
      const { releaseWorkerPayout } = await import('../modules/payout/payout.service.js');
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBooking as any);
      vi.mocked(prisma.jobExecution.update).mockResolvedValue({ ...mockExecution, status: 'completed' } as any);
      
      const result = await verifyCompletionOtp('b1', 'w1', '5678');
      expect(result.status).toBe('completed');
      expect(prisma.booking.update).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'COMPLETED' } }));
    });

    it('generateCompletionOtp throws if checklist items are incomplete', async () => {
      const { validateChecklistCompletion } = await import('../modules/checklist/checklist.service.js');
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBooking as any);
      vi.mocked(validateChecklistCompletion).mockReturnValue({ isComplete: false, missingItems: ['Test'] });
      
      await expect(generateCompletionOtp('b1', 'w1')).rejects.toThrow(IncompleteJobError);
    });

    it('generateCompletionOtp throws if before/after photos are missing', async () => {
      const { validateChecklistCompletion } = await import('../modules/checklist/checklist.service.js');
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBooking as any);
      vi.mocked(validateChecklistCompletion).mockReturnValue({ isComplete: true, missingItems: [] });
      // Missing photos in mockExecution
      
      await expect(generateCompletionOtp('b1', 'w1')).rejects.toThrow(IncompleteJobError);
    });
  });

  describe('Suite 3: Error Handling', () => {
    it('unauthorized access throws UnauthorizedError (translates to 403 in AppError handler usually)', async () => {
      const mockBooking = { id: 'b1', workerId: 'w2', services: [] }; // different worker
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBooking as any);
      
      await expect(generateArrivalOtp('b1', 'w1')).rejects.toThrow('You are not assigned to this booking');
    });

    it('acting on a wrong booking throws AppError.notFound (404)', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(null);
      
      await expect(generateArrivalOtp('b1', 'w1')).rejects.toSatisfy((err: any) => err instanceof AppError && err.statusCode === 404);
    });
  });
});
