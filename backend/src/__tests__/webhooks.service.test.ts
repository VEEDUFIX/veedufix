import { createHmac } from 'node:crypto';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BookingStatus, PaymentStatus, Prisma } from '@prisma/client';

const mocks = vi.hoisted(() => ({
  paymentFindUnique: vi.fn(),
  paymentFindMany: vi.fn(),
  paymentUpdate: vi.fn(),
  refundFindFirst: vi.fn(),
  refundFindUnique: vi.fn(),
  refundUpdate: vi.fn(),
  refundAggregate: vi.fn(),
  bookingUpdate: vi.fn(),
  bookingUpdateMany: vi.fn(),
  bookingFindUnique: vi.fn(),
  notificationCreate: vi.fn(),
  redisSet: vi.fn(),
  redisDel: vi.fn(),
  publishNotification: vi.fn(),
  publishTracking: vi.fn(),
  recordTimeline: vi.fn(),
  dispatchBooking: vi.fn(),
  raiseOpsAlert: vi.fn(),
  settleRefund: vi.fn(),
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    payment: { findUnique: mocks.paymentFindUnique, update: mocks.paymentUpdate, findMany: mocks.paymentFindMany },
    booking: { update: mocks.bookingUpdate, updateMany: mocks.bookingUpdateMany, findUnique: mocks.bookingFindUnique },
    refund: {
      findFirst: mocks.refundFindFirst,
      findUnique: mocks.refundFindUnique,
      update: mocks.refundUpdate,
      aggregate: mocks.refundAggregate
    },
    notification: { create: mocks.notificationCreate },
  },
}));
vi.mock('../lib/redis.js', () => ({ redis: { set: mocks.redisSet, del: mocks.redisDel } }));
vi.mock('../lib/logger.js', () => ({ logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn() } }));
vi.mock('../config/env.js', () => ({ env: { RAZORPAY_WEBHOOK_SECRET: 'test-webhook-secret' } }));
vi.mock('../lib/realtime.js', () => ({
  publishNotificationEvent: mocks.publishNotification,
  publishTrackingEvent: mocks.publishTracking,
}));
vi.mock('../lib/booking-timeline.js', () => ({ recordBookingTimelineEvent: mocks.recordTimeline }));
vi.mock('../modules/matching/matching.service.js', () => ({ dispatchBookingAfterPayment: mocks.dispatchBooking }));
vi.mock('../modules/ops/ops.service.js', () => ({ raiseOpsAlert: mocks.raiseOpsAlert }));
vi.mock('../modules/refund/refund.service.js', () => ({ settleRefundFromProvider: mocks.settleRefund }));

import { handleRazorpayWebhook, updatePaymentForWebhook } from '../modules/webhooks/webhooks.service.js';

describe('Razorpay webhook handling', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.redisSet.mockResolvedValue('OK');
    mocks.redisDel.mockResolvedValue(1);
    mocks.publishNotification.mockResolvedValue(undefined);
    mocks.publishTracking.mockResolvedValue(undefined);
    mocks.notificationCreate.mockResolvedValue(undefined);
    mocks.raiseOpsAlert.mockResolvedValue(undefined);
    mocks.settleRefund.mockResolvedValue(undefined);
    mocks.dispatchBooking.mockResolvedValue(undefined);
    mocks.refundAggregate.mockResolvedValue({ _sum: { amount: 0 } });
  });

  it('does not reopen or dispatch a booking cancelled before payment capture', async () => {
    const payment = {
      id: 'payment-row-1',
      bookingId: 'booking-1',
      providerRef: 'order-1',
      status: PaymentStatus.PENDING,
      amount: new Prisma.Decimal(50),
      notes: {},
      booking: {
        id: 'booking-1',
        code: 'VF-1001',
        customerId: 'customer-1',
        status: BookingStatus.CANCELLED_MANUAL,
        totalAmount: new Prisma.Decimal(50),
      },
    };
    mocks.paymentFindUnique.mockResolvedValue(payment);
    mocks.paymentUpdate.mockImplementation(async ({ data }: { data: { status: PaymentStatus; notes: unknown } }) => ({
      ...payment,
      status: data.status,
      notes: data.notes,
    }));

    await updatePaymentForWebhook('order-1', PaymentStatus.CAPTURED, { paymentId: 'rzp-payment-1' }, 5000);

    expect(mocks.paymentUpdate).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ status: PaymentStatus.CAPTURED }),
    }));
    expect(mocks.raiseOpsAlert).toHaveBeenCalledWith(expect.objectContaining({
      type: 'payment_mismatch',
      severity: 'critical',
      bookingId: 'booking-1',
      metadata: expect.objectContaining({ title: 'Payment captured after cancellation' }),
    }));
    expect(mocks.bookingUpdateMany).not.toHaveBeenCalled();
    expect(mocks.bookingUpdate).not.toHaveBeenCalled();
    expect(mocks.dispatchBooking).not.toHaveBeenCalled();
  });

  it('validates only the Razorpay portion when a booking used wallet balance', async () => {
    const payment = {
      id: 'payment-row-wallet',
      bookingId: 'booking-wallet',
      providerRef: 'order-wallet',
      status: PaymentStatus.PENDING,
      amount: new Prisma.Decimal(50),
      notes: { walletDeductAmountPaise: 5000 },
      booking: {
        id: 'booking-wallet',
        code: 'VF-WALLET',
        customerId: 'customer-wallet',
        status: BookingStatus.PENDING,
        totalAmount: new Prisma.Decimal(100),
      },
    };
    mocks.paymentFindUnique.mockResolvedValue(payment);
    mocks.paymentUpdate.mockImplementation(async ({ data }: { data: { status: PaymentStatus; notes: unknown } }) => ({
      ...payment,
      status: data.status,
      notes: data.notes,
    }));
    mocks.bookingUpdateMany.mockResolvedValue({ count: 1 });

    await updatePaymentForWebhook('order-wallet', PaymentStatus.CAPTURED, { paymentId: 'rzp-wallet' }, 5000);

    expect(mocks.paymentUpdate).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ status: PaymentStatus.CAPTURED }),
    }));
    expect(mocks.bookingUpdateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: { status: BookingStatus.ACCEPTED },
    }));
    expect(mocks.publishTracking).not.toHaveBeenCalledWith(expect.objectContaining({
      status: 'PAYMENT_AMOUNT_MISMATCH',
    }));
  });

  it('does not downgrade a captured payment when a delayed failure event arrives', async () => {
    const payment = {
      id: 'payment-captured',
      bookingId: 'booking-captured',
      providerRef: 'order-captured',
      status: PaymentStatus.CAPTURED,
      amount: new Prisma.Decimal(50),
      notes: { paymentId: 'rzp-payment-captured' },
      booking: {
        id: 'booking-captured',
        code: 'VF-CAPTURED',
        customerId: 'customer-captured',
        status: BookingStatus.ACCEPTED,
        totalAmount: new Prisma.Decimal(50),
      },
    };
    mocks.paymentFindUnique.mockResolvedValue(payment);

    await updatePaymentForWebhook('order-captured', PaymentStatus.FAILED, {
      paymentId: 'rzp-payment-captured',
    });

    expect(mocks.paymentUpdate).not.toHaveBeenCalled();
    expect(mocks.bookingUpdateMany).not.toHaveBeenCalled();
    expect(mocks.dispatchBooking).not.toHaveBeenCalled();
  });

  it('releases the delivery claim when processing fails so Razorpay can retry', async () => {
    const rawBody = JSON.stringify({
      event: 'payment.captured',
      payload: { payment: { entity: { id: 'rzp-payment-1', order_id: 'order-1', amount: 5000 } } },
    });
    const signature = createHmac('sha256', 'test-webhook-secret').update(rawBody).digest('hex');
    mocks.paymentFindUnique.mockRejectedValueOnce(new Error('temporary database error'));

    await expect(handleRazorpayWebhook(rawBody, signature, JSON.parse(rawBody))).rejects.toThrow(
      'temporary database error',
    );

    expect(mocks.redisDel).toHaveBeenCalledWith(expect.stringMatching(/^webhook:razorpay:/));
  });

  it('rejects malformed webhook signatures before claiming delivery', async () => {
    const body = { event: 'payment.captured' };
    const rawBody = JSON.stringify(body);

    await expect(handleRazorpayWebhook(rawBody, 'not-a-sha256-signature', body)).rejects.toMatchObject({
      statusCode: 401,
    });
    expect(mocks.redisSet).not.toHaveBeenCalled();
  });

  it('keeps a captured payment captured when a refund attempt fails', async () => {
    const payment = {
      id: 'payment-row-2',
      bookingId: 'booking-2',
      providerRef: 'order-2',
      status: PaymentStatus.CAPTURED,
      amount: new Prisma.Decimal(100),
      notes: { paymentId: 'rzp-payment-2' },
      booking: {
        id: 'booking-2',
        code: 'VF-1002',
        customerId: 'customer-2',
        status: BookingStatus.CANCELLED_MANUAL,
        totalAmount: new Prisma.Decimal(100),
      },
    };
    mocks.paymentFindMany.mockResolvedValue([payment]);
    mocks.refundFindFirst.mockResolvedValue({ id: 'refund-2', status: 'pending' });
    mocks.refundAggregate.mockResolvedValue({ _sum: { amount: 0 } });
    mocks.paymentUpdate.mockImplementation(async ({ data }: { data: { status?: PaymentStatus; notes: unknown } }) => ({
      ...payment,
      ...data,
      status: data.status ?? payment.status,
    }));

    const body = {
      event: 'refund.failed',
      payload: { refund: { entity: {
        id: 'rfnd-2',
        payment_id: 'rzp-payment-2',
        status: 'failed',
        amount: 10000,
      } } },
    };
    const rawBody = JSON.stringify(body);
    const signature = createHmac('sha256', 'test-webhook-secret').update(rawBody).digest('hex');
    await handleRazorpayWebhook(rawBody, signature, body);

    expect(mocks.settleRefund).toHaveBeenCalledWith(
      'refund-2',
      false,
      'failed',
      { providerRefundId: 'rfnd-2', providerAttemptId: null }
    );
    expect(mocks.paymentUpdate).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.not.objectContaining({ status: PaymentStatus.FAILED }),
    }));
    expect(mocks.bookingUpdate).not.toHaveBeenCalled();
  });

  it('does not mark a booking fully refunded when only a partial refund is processed', async () => {
    const payment = {
      id: 'payment-row-3',
      bookingId: 'booking-3',
      providerRef: 'order-3',
      status: PaymentStatus.CAPTURED,
      amount: new Prisma.Decimal(100),
      notes: { paymentId: 'rzp-payment-3' },
      booking: {
        id: 'booking-3',
        code: 'VF-1003',
        customerId: 'customer-3',
        status: BookingStatus.CANCELLED_MANUAL,
        totalAmount: new Prisma.Decimal(100),
      },
    };
    mocks.paymentFindMany.mockResolvedValue([payment]);
    mocks.refundFindFirst.mockResolvedValue(null);
    mocks.refundFindUnique.mockResolvedValue({
      id: 'refund-3',
      status: 'pending',
      razorpayRefundId: null,
      providerAttemptId: 'attempt-current',
    });
    mocks.refundAggregate.mockResolvedValue({ _sum: { amount: 40 } });
    mocks.paymentUpdate.mockImplementation(async ({ data }: { data: { status?: PaymentStatus; notes: unknown } }) => ({
      ...payment,
      ...data,
      status: data.status ?? payment.status,
    }));

    const body = {
      event: 'refund.processed',
      payload: { refund: { entity: {
        id: 'rfnd-3',
        payment_id: 'rzp-payment-3',
        status: 'processed',
        amount: 4000,
        notes: { refundRecordId: 'refund-3', refundAttemptId: 'attempt-current' },
      } } },
    };
    const rawBody = JSON.stringify(body);
    const signature = createHmac('sha256', 'test-webhook-secret').update(rawBody).digest('hex');
    await handleRazorpayWebhook(rawBody, signature, body);

    expect(mocks.settleRefund).toHaveBeenCalledWith(
      'refund-3',
      true,
      'processed',
      { providerRefundId: 'rfnd-3', providerAttemptId: 'attempt-current' }
    );
    expect(mocks.paymentUpdate).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.not.objectContaining({ status: PaymentStatus.REFUNDED }),
    }));
    expect(mocks.bookingUpdate).not.toHaveBeenCalled();
    expect(mocks.publishTracking).toHaveBeenCalledWith(expect.objectContaining({
      status: 'PAYMENT_PARTIALLY_REFUNDED',
    }));
  });

  it('ignores an internal refund record with a different provider refund ID', async () => {
    const payment = {
      id: 'payment-row-4',
      bookingId: 'booking-4',
      providerRef: 'order-4',
      status: PaymentStatus.CAPTURED,
      amount: new Prisma.Decimal(100),
      notes: { paymentId: 'rzp-payment-4' },
      booking: {
        id: 'booking-4',
        code: 'VF-1004',
        customerId: 'customer-4',
        status: BookingStatus.CANCELLED_MANUAL,
        totalAmount: new Prisma.Decimal(100),
      },
    };
    mocks.paymentFindMany.mockResolvedValue([payment]);
    mocks.refundFindFirst.mockResolvedValue(null);
    mocks.refundFindUnique.mockResolvedValue({
      id: 'refund-4',
      status: 'pending',
      razorpayRefundId: 'rfnd-other',
      providerAttemptId: 'attempt-current',
    });
    mocks.refundAggregate.mockResolvedValue({ _sum: { amount: 0 } });
    mocks.paymentUpdate.mockImplementation(async ({ data }: { data: { status?: PaymentStatus; notes: unknown } }) => ({
      ...payment,
      ...data,
      status: data.status ?? payment.status,
    }));

    const body = {
      event: 'refund.processed',
      payload: { refund: { entity: {
        id: 'rfnd-4',
        payment_id: 'rzp-payment-4',
        status: 'processed',
        amount: 4000,
        notes: { refundRecordId: 'refund-4', refundAttemptId: 'attempt-old' },
      } } },
    };
    const rawBody = JSON.stringify(body);
    const signature = createHmac('sha256', 'test-webhook-secret').update(rawBody).digest('hex');
    await handleRazorpayWebhook(rawBody, signature, body);

    expect(mocks.settleRefund).not.toHaveBeenCalled();
    expect(mocks.bookingUpdate).not.toHaveBeenCalled();
    expect(mocks.paymentUpdate).not.toHaveBeenCalled();
  });
});
