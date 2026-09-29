import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createHmac } from 'node:crypto';
import { Prisma } from '@prisma/client';

// ─── Mock all external modules BEFORE importing ───────────────────────────────

const { mockRazorpayOrderCreate, mockRazorpayPaymentFetch, mockOpsAlert, mockDispatch } = vi.hoisted(() => ({
  mockRazorpayOrderCreate: vi.fn(),
  mockRazorpayPaymentFetch: vi.fn(),
  mockOpsAlert: vi.fn(),
  mockDispatch: vi.fn(),
}));
const { mockGetCustomerScheduleSlots } = vi.hoisted(() => ({
  mockGetCustomerScheduleSlots: vi.fn(),
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn((cb) => cb(prismaMockTx)),
    user: { findUnique: vi.fn(), update: vi.fn() },
    city: { findUnique: vi.fn(), findFirst: vi.fn() },
    savedAddress: { findFirst: vi.fn() },
    serviceArea: { findFirst: vi.fn() },
    address: { findFirst: vi.fn(), create: vi.fn() },
    service: { findMany: vi.fn() },
    coupon: { findFirst: vi.fn() },
    payment: { create: vi.fn(), updateMany: vi.fn(), update: vi.fn(), findFirst: vi.fn() },
    booking: { findUnique: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
    jobExecution: { upsert: vi.fn(), update: vi.fn(), updateMany: vi.fn(), findUnique: vi.fn() },
    walletTransaction: { create: vi.fn() },
    bookingService: { createMany: vi.fn() },
  },
}));

const prismaMockTx = {
  booking: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  jobExecution: { upsert: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  bookingService: { createMany: vi.fn() },
  payment: { create: vi.fn(), updateMany: vi.fn() },
  user: { update: vi.fn(), updateMany: vi.fn(), findUnique: vi.fn() },
  walletTransaction: { create: vi.fn() },
};

vi.mock('../lib/redis.js', () => ({
  redis: { set: vi.fn(), get: vi.fn(), del: vi.fn(), incr: vi.fn().mockResolvedValue(1), expire: vi.fn() },
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

vi.mock('../modules/ops/ops.service.js', () => ({ raiseOpsAlert: mockOpsAlert }));
vi.mock('../modules/matching/matching.service.js', () => ({ dispatchBookingAfterPayment: mockDispatch }));

vi.mock('../modules/service-area/service-area.service.js', () => ({
  assertServiceablePincode: vi.fn(),
}));
vi.mock('../modules/availability/availability.service.js', () => ({
  getCustomerScheduleSlots: mockGetCustomerScheduleSlots,
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
        create: mockRazorpayOrderCreate,
      };
      payments = { fetch: mockRazorpayPaymentFetch };
    },
  };
});

// ─── Imports ──────────────────────────────────────────────────────────────────

import { createPaymentOrder, verifyPayment } from '../modules/payments/payments.service.js';
import { 
  generateArrivalOtp, 
  verifyArrivalOtp,
  generateCompletionOtp,
  verifyCompletionOtp
} from '../modules/job-execution/job-execution.service.js';
import { JobStateConflictError, OtpAttemptLimitError } from '../modules/job-execution/job-execution.service.js';
import { prisma } from '../lib/prisma.js';
import { redis } from '../lib/redis.js';
import { AppError } from '../lib/app-error.js';
import { IncompleteJobError } from '../modules/job-execution/job-execution.service.js';

describe('Booking Flow', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockGetCustomerScheduleSlots.mockResolvedValue([]);
    mockRazorpayOrderCreate.mockResolvedValue({ id: 'order_123' });
    mockRazorpayPaymentFetch.mockResolvedValue({
      id: 'pay_123', order_id: 'order_123', amount: 5000, currency: 'INR', status: 'captured',
    });
    vi.mocked(prisma.savedAddress.findFirst).mockResolvedValue(null);
    vi.mocked(prisma.serviceArea.findFirst).mockResolvedValue(null);
    vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
  });

  describe('Suite 1: Booking Creation (createPaymentOrder)', () => {
    it('rejects a scheduled booking when the requested slot is no longer available', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: 'u1', cityId: 'chennai', name: 'Test', email: null, phone: null,
      } as any);
      vi.mocked(prisma.savedAddress.findFirst).mockResolvedValue({
        id: 'saved-1', userId: 'u1', label: 'Home', addressLine1: 'Main road',
        addressLine2: null, landmark: null, city: 'Chennai', pincode: '600001',
        lat: 13.08, lng: 80.27, isDefault: true,
      } as any);
      vi.mocked(prisma.city.findFirst).mockResolvedValue({ id: 'chennai', name: 'Chennai' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'legacy-1', userId: 'u1', pincode: '600001' } as any);
      vi.mocked(prisma.service.findMany).mockResolvedValue([{
        id: 's1', name: 'AC Repair', isActive: true,
        startingPrice: new Prisma.Decimal(500), gstRate: new Prisma.Decimal(18),
        gstApplicable: true, sacCode: '9987', subcategory: { id: 'sub1', name: 'AC' }, pricingRules: [],
      }] as any);

      const scheduledFor = new Date(Date.now() + 24 * 60 * 60 * 1000);
      await expect(createPaymentOrder({
        userId: 'u1',
        addressId: 'saved-1',
        bookingType: 'scheduled',
        scheduledFor,
        items: [{ serviceId: 's1' }],
      })).rejects.toSatisfy((error: any) => error instanceof AppError && error.statusCode === 409);

      expect(mockGetCustomerScheduleSlots).toHaveBeenCalledWith(expect.objectContaining({
        userId: 'u1',
        addressId: 'saved-1',
        serviceIds: ['s1'],
        days: 1,
      }));
      expect(prismaMockTx.booking.create).not.toHaveBeenCalled();
      expect(mockRazorpayOrderCreate).not.toHaveBeenCalled();
    });

    it('uses the selected saved address and its service city', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: 'u1', cityId: 'old-city', name: 'Test', email: null, phone: null,
      } as any);
      vi.mocked(prisma.savedAddress.findFirst).mockResolvedValue({
        id: 'saved-1', userId: 'u1', label: 'Home', addressLine1: 'Main road',
        addressLine2: null, landmark: null, city: 'Chennai', pincode: '600001',
        lat: 13.08, lng: 80.27, isDefault: true,
      } as any);
      vi.mocked(prisma.city.findFirst).mockResolvedValue({ id: 'chennai', name: 'Chennai' } as any);
      vi.mocked(prisma.address.findFirst)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({ id: 'legacy-1', userId: 'u1', pincode: '600001' } as any);
      vi.mocked(prisma.address.create).mockResolvedValue({ id: 'legacy-1' } as any);
      vi.mocked(prisma.service.findMany).mockResolvedValue([{
        id: 's1', name: 'AC Repair', isActive: true,
        startingPrice: new Prisma.Decimal(500), gstRate: new Prisma.Decimal(18),
        gstApplicable: true, sacCode: '9987', subcategory: { id: 'sub1', name: 'AC' }, pricingRules: [],
      }] as any);
      prismaMockTx.booking.create.mockResolvedValue({ id: 'b1', code: 'BK-123' });

      const result = await createPaymentOrder({
        userId: 'u1', cityId: 'old-city', addressId: 'saved-1',
        items: [{ serviceId: 's1', quantity: 1 }],
      });

      expect(result.bookingId).toBe('b1');
      expect(prisma.address.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ cityId: 'chennai', pincode: '600001' }),
      }));
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'u1' }, data: { cityId: 'chennai' },
      });
    });

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
      expect(prisma.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({
          notes: expect.objectContaining({
            walletDeductAmountPaise: 0,
            subtotalAmountPaise: 50000,
            discountAmountPaise: 0,
            orderId: 'order_123',
            totalAmountPaise: 50000,
            items: [expect.objectContaining({ serviceId: 's1', quantity: 1 })],
          }),
        }),
      }));
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

    it('restores wallet funds and cancels the booking if Razorpay order creation fails', async () => {
      vi.mocked(prisma.user.findUnique)
        .mockResolvedValueOnce({ id: 'u1', cityId: 'c1', name: 'Test', email: null, phone: null } as any)
        .mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(100) } as any);
      vi.mocked(prisma.city.findUnique).mockResolvedValue({ id: 'c1', name: 'City' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
      vi.mocked(prisma.service.findMany).mockResolvedValue([{
        id: 's1', name: 'AC Repair', isActive: true,
        startingPrice: new Prisma.Decimal(500), gstRate: new Prisma.Decimal(18),
        gstApplicable: true, sacCode: '9987', subcategory: { id: 'sub1', name: 'AC' }, pricingRules: [],
      }] as any);
      prismaMockTx.booking.create.mockResolvedValue({ id: 'b1', code: 'BK-123' });
      prismaMockTx.user.updateMany.mockResolvedValueOnce({ count: 1 });
      prismaMockTx.user.findUnique.mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(0) });
      prismaMockTx.user.update.mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(100) });
      mockRazorpayOrderCreate.mockRejectedValueOnce(new Error('Razorpay unavailable'));

      await expect(createPaymentOrder({
        userId: 'u1',
        cityId: 'c1',
        items: [{ serviceId: 's1', quantity: 1 }],
        useWalletBalance: true,
      })).rejects.toThrow('Razorpay unavailable');

      expect(prismaMockTx.booking.update).toHaveBeenCalledWith({
        where: { id: 'b1' },
        data: { status: 'CANCELLED' },
      });
      expect(prismaMockTx.user.update).toHaveBeenLastCalledWith({
        where: { id: 'u1' },
        data: { walletBalance: { increment: new Prisma.Decimal(100) } },
      });
      expect(prismaMockTx.user.updateMany).toHaveBeenCalledWith({
        where: { id: 'u1', walletBalance: { gte: new Prisma.Decimal(100) } },
        data: { walletBalance: { decrement: new Prisma.Decimal(100) } },
      });
      expect(prismaMockTx.walletTransaction.create).toHaveBeenLastCalledWith({
        data: expect.objectContaining({
          userId: 'u1',
          type: 'WALLET_CREDIT',
          referenceType: 'PAYMENT_ORDER_FAILED',
          referenceId: 'b1',
          amount: new Prisma.Decimal(100),
        }),
      });
    });

    it('rejects a wallet debit when the balance changed before checkout committed', async () => {
      vi.mocked(prisma.user.findUnique)
        .mockResolvedValueOnce({ id: 'u1', cityId: 'c1', name: 'Test', email: null, phone: null } as any)
        .mockResolvedValueOnce({ walletBalance: new Prisma.Decimal(100) } as any);
      vi.mocked(prisma.city.findUnique).mockResolvedValue({ id: 'c1', name: 'City' } as any);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({ id: 'a1', userId: 'u1', pincode: '600001' } as any);
      vi.mocked(prisma.service.findMany).mockResolvedValue([{
        id: 's1', name: 'AC Repair', isActive: true,
        startingPrice: new Prisma.Decimal(500), gstRate: new Prisma.Decimal(18),
        gstApplicable: true, sacCode: '9987', subcategory: { id: 'sub1', name: 'AC' }, pricingRules: [],
      }] as any);
      prismaMockTx.booking.create.mockResolvedValue({ id: 'b-wallet-race', code: 'BK-RACE' });
      prismaMockTx.user.updateMany.mockResolvedValueOnce({ count: 0 });

      await expect(createPaymentOrder({
        userId: 'u1',
        cityId: 'c1',
        items: [{ serviceId: 's1', quantity: 1 }],
        useWalletBalance: true,
      })).rejects.toSatisfy((error: any) => error instanceof AppError && error.statusCode === 409);

      expect(mockRazorpayOrderCreate).not.toHaveBeenCalled();
      expect(prismaMockTx.walletTransaction.create).not.toHaveBeenCalled();
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

  it('does not reopen a cancelled booking when payment verification completes late', async () => {
    const payment = {
      id: 'payment-1',
      bookingId: 'booking-1',
      providerRef: 'order_123',
      status: 'PENDING',
      amount: new Prisma.Decimal(50),
      notes: { walletDeductAmountPaise: 5000 },
      booking: {
        id: 'booking-1',
        code: 'VF-1001',
        customerId: 'u1',
        totalAmount: new Prisma.Decimal(100),
        status: 'CANCELLED_MANUAL',
      },
    };
    vi.mocked(prisma.payment.findFirst).mockResolvedValue(payment as any);
    vi.mocked(prisma.payment.update).mockResolvedValue({ ...payment, status: 'CAPTURED' } as any);
    vi.mocked(prisma.booking.updateMany).mockResolvedValue({ count: 0 } as any);
    mockOpsAlert.mockResolvedValue(undefined);
    const signature = createHmac('sha256', 'test_secret')
      .update('order_123|pay_123')
      .digest('hex');

    const result = await verifyPayment({
      userId: 'u1',
      bookingId: 'booking-1',
      razorpayOrderId: 'order_123',
      razorpayPaymentId: 'pay_123',
      razorpaySignature: signature,
    });

    expect(result.status).toBe('CAPTURED');
    expect(prisma.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({
        status: expect.objectContaining({ notIn: expect.arrayContaining(['CANCELLED_MANUAL']) }),
      }),
    }));
    expect(mockOpsAlert).toHaveBeenCalledWith(expect.objectContaining({ severity: 'critical' }));
    expect(mockDispatch).not.toHaveBeenCalled();
  });

  it('does not downgrade an already-refunded payment during late verification', async () => {
    const payment = {
      id: 'payment-refunded',
      bookingId: 'booking-refunded',
      providerRef: 'order_123',
      status: 'REFUNDED',
      amount: new Prisma.Decimal(50),
      notes: { paymentId: 'pay_old' },
      booking: {
        id: 'booking-refunded',
        code: 'VF-REFUNDED',
        customerId: 'u1',
        totalAmount: new Prisma.Decimal(100),
        status: 'REFUNDED',
      },
    };
    vi.mocked(prisma.payment.findFirst).mockResolvedValue(payment as any);
    mockOpsAlert.mockResolvedValue(undefined);
    const signature = createHmac('sha256', 'test_secret')
      .update('order_123|pay_123')
      .digest('hex');

    const result = await verifyPayment({
      userId: 'u1',
      bookingId: 'booking-refunded',
      razorpayOrderId: 'order_123',
      razorpayPaymentId: 'pay_123',
      razorpaySignature: signature,
    });

    expect(result.status).toBe('REFUNDED');
    expect(prisma.payment.update).not.toHaveBeenCalled();
    expect(mockOpsAlert).toHaveBeenCalledWith(expect.objectContaining({
      sourceId: 'capture-after-refund:payment-refunded',
    }));
  });

  it('rejects malformed payment signatures before contacting Razorpay', async () => {
    vi.mocked(prisma.payment.findFirst).mockResolvedValue({
      id: 'payment-signature',
      bookingId: 'booking-signature',
      providerRef: 'order_123',
      status: 'PENDING',
      amount: new Prisma.Decimal(50),
      notes: {},
      booking: {
        id: 'booking-signature',
        code: 'VF-SIGNATURE',
        customerId: 'u1',
        totalAmount: new Prisma.Decimal(50),
        status: 'PENDING',
      },
    } as any);

    await expect(verifyPayment({
      userId: 'u1',
      bookingId: 'booking-signature',
      razorpayOrderId: 'order_123',
      razorpayPaymentId: 'pay_123',
      razorpaySignature: 'invalid',
    })).rejects.toSatisfy((error: any) => error instanceof AppError && error.statusCode === 400);

    expect(mockRazorpayPaymentFetch).not.toHaveBeenCalled();
  });

  describe('Suite 2: Job Execution Flow', () => {
    const mockExecution = {
      bookingId: 'b1', status: 'assigned', beforePhotos: [], afterPhotos: [], checklist: null,
      otpStart: '1234', otpStartExpiresAt: new Date(Date.now() + 10000),
      otpEnd: '5678', otpEndExpiresAt: new Date(Date.now() + 10000)
    };
    const mockBooking = {
      id: 'b1', workerId: 'w1', customerId: 'c1', services: [{ serviceId: 's1' }], jobExecution: mockExecution,
      status: 'WORKER_ASSIGNED',
      worker: { userId: 'wu1' }
    };

    it('generateArrivalOtp marks booking as ARRIVED and returns OTP', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBooking as any);
      prismaMockTx.booking.updateMany.mockResolvedValue({ count: 1 } as any);
      prismaMockTx.jobExecution.upsert.mockResolvedValue({ ...mockExecution, status: 'arrived' } as any);
      
      const result = await generateArrivalOtp('b1', 'w1', { workerLat: 10, workerLng: 20 });
      expect(result.status).toBe('arrived');
      expect(prismaMockTx.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'ARRIVED' } }));
    });

    it('verifyArrivalOtp transitions booking to IN_PROGRESS', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBooking,
        status: 'ARRIVED',
        jobExecution: { ...mockExecution, status: 'arrived', otpStartVerifiedAt: null },
      } as any);
      prismaMockTx.booking.updateMany.mockResolvedValue({ count: 1 } as any);
      prismaMockTx.jobExecution.updateMany.mockResolvedValue({ count: 1 } as any);
      
      const result = await verifyArrivalOtp('b1', 'w1', '1234');
      expect(result.status).toBe('in_progress');
      expect(prismaMockTx.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'IN_PROGRESS' } }));
    });

    it('does not allow completion OTP before the arrival OTP starts the job', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(mockBooking as any);

      await expect(generateCompletionOtp('b1', 'w1')).rejects.toBeInstanceOf(JobStateConflictError);
    });

    it('verifyCompletionOtp marks booking as COMPLETED and triggers payout', async () => {
      const { releaseWorkerPayout } = await import('../modules/payout/payout.service.js');
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBooking,
        status: 'IN_PROGRESS',
        jobExecution: {
          ...mockExecution,
          status: 'in_progress',
          otpStartVerifiedAt: new Date(),
          beforePhotos: ['https://cdn.example/before.jpg'],
          afterPhotos: ['https://cdn.example/after.jpg'],
          checklist: [{ id: 'required', required: true, completed: true }],
        },
      } as any);
      prismaMockTx.booking.updateMany.mockResolvedValue({ count: 1 } as any);
      prismaMockTx.jobExecution.updateMany.mockResolvedValue({ count: 1 } as any);
      
      const result = await verifyCompletionOtp('b1', 'w1', '5678');
      expect(result.status).toBe('completed');
      expect(prismaMockTx.booking.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'COMPLETED' } }));
    });

    it('limits repeated incorrect completion-code attempts across app instances', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBooking,
        status: 'IN_PROGRESS',
        jobExecution: {
          ...mockExecution,
          status: 'in_progress',
          otpStartVerifiedAt: new Date(),
          otpEnd: '5678',
          otpEndExpiresAt: new Date(Date.now() + 10000),
        },
      } as any);
      vi.mocked(redis.incr).mockResolvedValue(6);

      await expect(verifyCompletionOtp('b1', 'w1', '1111')).rejects.toBeInstanceOf(OtpAttemptLimitError);
      expect(prismaMockTx.booking.updateMany).not.toHaveBeenCalled();
    });

    it('generateCompletionOtp throws if checklist items are incomplete', async () => {
      const { validateChecklistCompletion } = await import('../modules/checklist/checklist.service.js');
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBooking,
        status: 'IN_PROGRESS',
        jobExecution: { ...mockExecution, status: 'in_progress', otpStartVerifiedAt: new Date() },
      } as any);
      vi.mocked(validateChecklistCompletion).mockReturnValue({ isComplete: false, missingItems: ['Test'] });
      
      await expect(generateCompletionOtp('b1', 'w1')).rejects.toThrow(IncompleteJobError);
    });

    it('generateCompletionOtp throws if before/after photos are missing', async () => {
      const { validateChecklistCompletion } = await import('../modules/checklist/checklist.service.js');
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBooking,
        status: 'IN_PROGRESS',
        jobExecution: { ...mockExecution, status: 'in_progress', otpStartVerifiedAt: new Date() },
      } as any);
      vi.mocked(validateChecklistCompletion).mockReturnValue({ isComplete: true, missingItems: [] });
      // Missing photos in mockExecution
      
      await expect(generateCompletionOtp('b1', 'w1')).rejects.toThrow(IncompleteJobError);
    });

    it('requires before photos on the server before issuing a completion code', async () => {
      const { validateChecklistCompletion } = await import('../modules/checklist/checklist.service.js');
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        ...mockBooking,
        status: 'IN_PROGRESS',
        jobExecution: {
          ...mockExecution,
          status: 'in_progress',
          otpStartVerifiedAt: new Date(),
          beforePhotos: [],
          afterPhotos: ['https://cdn.example/after.jpg'],
          checklist: [{ id: 'required', required: true, completed: true }],
        },
      } as any);
      vi.mocked(validateChecklistCompletion).mockReturnValue({ isComplete: true, missingItems: [] });

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
