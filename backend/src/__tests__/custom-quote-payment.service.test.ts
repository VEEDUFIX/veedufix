import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PaymentStatus } from '@prisma/client';

const quoteOrderCreate = vi.hoisted(() => vi.fn());
const raiseOpsAlert = vi.hoisted(() => vi.fn());
const tx = {
  payment: { findUnique: vi.fn(), updateMany: vi.fn(), update: vi.fn(), create: vi.fn() },
  customQuoteRevision: { updateMany: vi.fn(), findUnique: vi.fn() },
  booking: { update: vi.fn() },
  invoice: { findUnique: vi.fn(), update: vi.fn() },
  $queryRaw: vi.fn()
};
vi.mock('../lib/prisma.js', () => ({
  prisma: {
    payment: { findUnique: vi.fn(), create: vi.fn(), updateMany: vi.fn() },
    customQuoteRevision: { findFirst: vi.fn(), updateMany: vi.fn() },
    $transaction: vi.fn(async (callback: (client: typeof tx) => unknown) => callback(tx))
  }
}));
vi.mock('../config/env.js', () => ({
  env: { RAZORPAY_KEY_ID: 'test-key', RAZORPAY_KEY_SECRET: 'test-secret' }
}));
vi.mock('../modules/ops/ops.service.js', () => ({ raiseOpsAlert }));
vi.mock('razorpay', () => ({
  default: class MockRazorpay {
    orders = { create: quoteOrderCreate };
  }
}));
import { prisma } from '../lib/prisma.js';
import {
  createCustomQuotePaymentOrder,
  settleCustomQuotePayment
} from '../modules/bookings/custom-quote-payment.service.js';

const payment = {
  id: 'payment-quote-1', bookingId: 'booking-1', status: PaymentStatus.PENDING,
  amount: 300, notes: {}, customQuoteRevisionId: 'revision-1',
  customQuoteRevision: {
    id: 'revision-1', bookingId: 'booking-1', version: 1, status: 'ACCEPTED',
    paymentStatus: 'PAYMENT_PENDING', amount: 300, taxAmount: 45,
    itemized: [{ label: 'Materials', qty: 2, unitPrice: 150 }]
  },
  booking: { id: 'booking-1' }
};

describe('custom quote payment settlement', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    quoteOrderCreate.mockResolvedValue({ id: 'rzp-order-1' });
    vi.mocked(prisma.payment.findUnique).mockResolvedValue(payment as never);
    tx.payment.findUnique.mockResolvedValue(payment);
    tx.$queryRaw.mockResolvedValue([]);
    vi.mocked(prisma.payment.create).mockResolvedValue({} as never);
    vi.mocked(prisma.payment.updateMany).mockResolvedValue({ count: 1 } as never);
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({
      id: 'revision-1', bookingId: 'booking-1', version: 1, status: 'ACCEPTED',
      paymentStatus: 'ORDER_CREATING', amount: 300, taxAmount: 45,
      booking: {
        id: 'booking-1', customerId: 'customer-1', code: 'VF-1',
        customer: { name: 'Customer', email: null, phone: null }
      },
      payments: []
    } as never);
    vi.mocked(prisma.customQuoteRevision.updateMany).mockResolvedValue({ count: 1 } as never);
    tx.payment.create.mockResolvedValue({} as never);
    tx.payment.updateMany.mockResolvedValue({ count: 1 });
    tx.payment.update.mockResolvedValue({} as never);
    tx.customQuoteRevision.updateMany.mockResolvedValue({ count: 1 });
    tx.customQuoteRevision.findUnique.mockResolvedValue(null);
    tx.invoice.findUnique.mockResolvedValue({ id: 'invoice-1', lineItems: [] } as never);
  });

  it('reclaims a stale ORDER_CREATING quote payment claim with an ownership lease', async () => {
    const order = await createCustomQuotePaymentOrder('booking-1', 'customer-1');
    const claim = vi.mocked(prisma.customQuoteRevision.updateMany).mock.calls[0][0];
    const claimAt = claim.data.updatedAt;

    expect(claim.where.OR).toEqual(expect.arrayContaining([
      expect.objectContaining({ paymentStatus: { in: ['PENDING', 'PAYMENT_FAILED'] } }),
      expect.objectContaining({
        paymentStatus: 'ORDER_CREATING',
        updatedAt: expect.objectContaining({ lt: expect.any(Date) })
      })
    ]));
    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ paymentStatus: 'ORDER_CREATING', updatedAt: claimAt }),
      data: { paymentStatus: 'PAYMENT_PENDING' }
    }));
    expect(order.orderId).toBe('rzp-order-1');
  });

  it('does not create a payment order for a quote on a closed booking', async () => {
    vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({
      id: 'revision-1', bookingId: 'booking-1', version: 1, status: 'ACCEPTED',
      paymentStatus: 'PENDING', amount: 300,
      booking: {
        id: 'booking-1', customerId: 'customer-1', code: 'VF-1', status: 'CANCELLED_MANUAL',
        customer: { name: 'Customer', email: null, phone: null }
      },
      payments: []
    } as never);
    await expect(createCustomQuotePaymentOrder('booking-1', 'customer-1'))
      .rejects.toMatchObject({ statusCode: 409 });
    expect(quoteOrderCreate).not.toHaveBeenCalled();
  });

  it.each(['LEGACY_UNVERIFIED', 'REFUNDED', 'PARTIALLY_REFUNDED'])(
    'rejects a %s quote payment state before creating an order',
    async (paymentStatus) => {
      vi.mocked(prisma.customQuoteRevision.findFirst).mockResolvedValue({
        id: 'revision-1', bookingId: 'booking-1', version: 1, status: 'ACCEPTED',
        paymentStatus, amount: 300,
        booking: {
          id: 'booking-1', customerId: 'customer-1', code: 'VF-1',
          customer: { name: 'Customer', email: null, phone: null }
        },
        payments: []
      } as never);

      await expect(createCustomQuotePaymentOrder('booking-1', 'customer-1'))
        .rejects.toMatchObject({
          statusCode: 409,
          message: 'Only an accepted, unpaid quote can be charged'
        });
      expect(quoteOrderCreate).not.toHaveBeenCalled();
      expect(prisma.customQuoteRevision.updateMany).not.toHaveBeenCalled();
    }
  );

  it('adds captured quote amount and tax to booking and invoice once', async () => {
    await settleCustomQuotePayment('payment-quote-1', PaymentStatus.CAPTURED, 30000, { paymentId: 'rzp-pay' });
    expect(tx.booking.update).toHaveBeenCalledWith(expect.objectContaining({
      data: {
        subtotalAmount: { increment: 300 },
        taxAmount: { increment: 45 },
        totalAmount: { increment: 300 }
      }
    }));
    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ paymentStatus: { in: ['PENDING', 'ORDER_CREATING', 'PAYMENT_PENDING', 'PAYMENT_FAILED'] } }),
      data: expect.objectContaining({ paymentStatus: 'PAID' })
    }));
    expect(tx.invoice.update).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        subtotalAmount: { increment: 300 },
        totalGstAmount: { increment: 45 },
        grandTotal: { increment: 300 }
      })
    }));
  });

  it.each(['REFUNDED', 'PARTIALLY_REFUNDED'])(
    'preserves %s state and records a mismatched late capture', async (paymentStatus) => {
      vi.mocked(prisma.payment.findUnique).mockResolvedValue({
        ...payment,
        customQuoteRevision: { ...payment.customQuoteRevision, paymentStatus }
      } as never);

      await expect(settleCustomQuotePayment(
        'payment-quote-1', PaymentStatus.CAPTURED, 29000, { paymentId: 'late-mismatch' }
      )).resolves.toEqual({ mismatch: true });

      expect(tx.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
        where: {
          id: 'payment-quote-1',
          status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] }
        },
        data: expect.objectContaining({
          status: PaymentStatus.CAPTURED,
          notes: expect.objectContaining({ amountMismatch: true, capturedAfterQuoteRefund: true })
        })
      }));
      expect(tx.customQuoteRevision.updateMany).not.toHaveBeenCalled();
      expect(raiseOpsAlert).toHaveBeenCalledWith(expect.objectContaining({
        sourceId: 'quote-capture-after-refund:payment-quote-1',
        severity: 'critical'
      }));
    }
  );

  it('records and alerts a quote capture after the booking has closed without settling the quote', async () => {
    tx.$queryRaw.mockResolvedValueOnce([{ status: 'CANCELLED_MANUAL' }]);

    const result = await settleCustomQuotePayment(
      'payment-quote-1',
      PaymentStatus.CAPTURED,
      30000,
      { paymentId: 'late-provider-payment' }
    );

    expect(result).toEqual({ capturedAfterClose: true, status: PaymentStatus.CAPTURED });
    expect(tx.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'payment-quote-1', status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] } },
      data: expect.objectContaining({
        status: PaymentStatus.CAPTURED,
        notes: expect.objectContaining({
          capturedAfterBookingClosed: true,
          expectedAmountPaise: 30000,
          capturedAmountPaise: 30000
        })
      })
    }));
    expect(tx.customQuoteRevision.updateMany).not.toHaveBeenCalled();
    expect(tx.booking.update).not.toHaveBeenCalled();
    expect(tx.invoice.update).not.toHaveBeenCalled();
    expect(raiseOpsAlert).toHaveBeenCalledWith(expect.objectContaining({
      type: 'payment_mismatch',
      sourceId: 'quote-capture-after-close:payment-quote-1',
      severity: 'critical'
    }));
  });

  it('does not apply booking totals again for a duplicate provider event', async () => {
    tx.payment.updateMany.mockResolvedValueOnce({ count: 0 });
    await settleCustomQuotePayment('payment-quote-1', PaymentStatus.CAPTURED, 30000, { webhookEvent: 'payment.captured' });
    expect(tx.booking.update).not.toHaveBeenCalled();
    expect(tx.invoice.update).not.toHaveBeenCalled();
  });

  it('settles a successful capture after a failed payment attempt', async () => {
    vi.mocked(prisma.payment.findUnique).mockResolvedValue({
      ...payment,
      status: PaymentStatus.FAILED,
      customQuoteRevision: { ...payment.customQuoteRevision, paymentStatus: 'PAYMENT_FAILED' }
    } as never);

    await settleCustomQuotePayment('payment-quote-1', PaymentStatus.CAPTURED, undefined, { paymentId: 'retry-pay' });

    expect(tx.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'payment-quote-1', status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] } }
    }));
    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ paymentStatus: { in: ['PENDING', 'ORDER_CREATING', 'PAYMENT_PENDING', 'PAYMENT_FAILED'] } }),
      data: expect.objectContaining({ paymentStatus: 'PAID' })
    }));
    expect(tx.booking.update).toHaveBeenCalledTimes(1);
  });
  it('records a mismatched provider capture on a failed payment without changing booking totals', async () => {
    vi.mocked(prisma.payment.findUnique).mockResolvedValue({
      ...payment,
      status: PaymentStatus.FAILED
    } as never);
    await settleCustomQuotePayment('payment-quote-1', PaymentStatus.CAPTURED, 10000, { paymentId: 'wrong-amount' });
    expect(tx.booking.update).not.toHaveBeenCalled();
    expect(tx.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: {
        id: 'payment-quote-1',
        status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] }
      },
      data: expect.objectContaining({
        status: PaymentStatus.CAPTURED,
        notes: expect.objectContaining({ amountMismatch: true, expectedAmountPaise: 30000, capturedAmountPaise: 10000 })
      })
    }));
  });

  it('records and alerts on a second capture after the quote is already paid', async () => {
    vi.mocked(prisma.payment.findUnique).mockResolvedValue({
      ...payment,
      id: 'payment-quote-retry',
      status: PaymentStatus.PENDING,
      customQuoteRevision: {
        ...payment.customQuoteRevision,
        paymentStatus: 'PAID'
      }
    } as never);

    const result = await settleCustomQuotePayment(
      'payment-quote-retry',
      PaymentStatus.CAPTURED,
      30000,
      { paymentId: 'provider-payment-retry' }
    );

    expect(result).toEqual({ duplicateCapture: true, mismatch: false });
    expect(prisma.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: {
        id: 'payment-quote-retry',
        status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] }
      },
      data: expect.objectContaining({
        status: PaymentStatus.CAPTURED,
        notes: expect.objectContaining({
          duplicateQuoteCapture: true,
          capturedAmountPaise: 30000
        })
      })
    }));
    expect(raiseOpsAlert).toHaveBeenCalledWith(expect.objectContaining({
      type: 'payment_mismatch',
      sourceId: 'duplicate-quote-capture:payment-quote-retry',
      severity: 'critical'
    }));
    expect(tx.booking.update).not.toHaveBeenCalled();
    expect(tx.invoice.update).not.toHaveBeenCalled();
  });

  it.each(['REFUNDED', 'PARTIALLY_REFUNDED'])('records and alerts a capture after a %s quote refund without settling the quote again', async (paymentStatus) => {
    vi.mocked(prisma.payment.findUnique).mockResolvedValue({
      ...payment,
      customQuoteRevision: { ...payment.customQuoteRevision, paymentStatus }
    } as never);
    tx.customQuoteRevision.updateMany.mockResolvedValueOnce({ count: 0 });
    tx.customQuoteRevision.findUnique.mockResolvedValueOnce({ paymentStatus });

    const result = await settleCustomQuotePayment(
      'payment-quote-1', PaymentStatus.CAPTURED, 30000, { paymentId: 'late-capture' }
    );

    expect(result).toEqual({ capturedAfterRefund: true, status: PaymentStatus.CAPTURED });
    expect(tx.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'payment-quote-1', status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] } },
      data: expect.objectContaining({ status: PaymentStatus.CAPTURED })
    }));
    expect(tx.payment.update).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'payment-quote-1' },
      data: expect.objectContaining({ notes: expect.objectContaining({ capturedAfterQuoteRefund: true }) })
    }));
    expect(raiseOpsAlert).toHaveBeenCalledWith(expect.objectContaining({
      type: 'payment_mismatch', sourceId: 'quote-capture-after-refund:payment-quote-1', severity: 'critical'
    }));
    expect(tx.booking.update).not.toHaveBeenCalled();
    expect(tx.invoice.update).not.toHaveBeenCalled();
  });

  it('retries the mismatch alert for an already-recorded capture after a refund', async () => {
    vi.mocked(prisma.payment.findUnique).mockResolvedValue({
      ...payment,
      status: PaymentStatus.CAPTURED,
      notes: { capturedAfterQuoteRefund: true },
      customQuoteRevision: { ...payment.customQuoteRevision, paymentStatus: 'REFUNDED' }
    } as never);

    const result = await settleCustomQuotePayment('payment-quote-1', PaymentStatus.CAPTURED, 30000);

    expect(result).toEqual({ capturedAfterRefund: true, status: PaymentStatus.CAPTURED });
    expect(raiseOpsAlert).toHaveBeenCalledOnce();
    expect(tx.payment.updateMany).not.toHaveBeenCalled();
    expect(tx.booking.update).not.toHaveBeenCalled();
  });

  it('does not alert for a repeated delivery of the already captured payment', async () => {
    vi.mocked(prisma.payment.findUnique).mockResolvedValue({
      ...payment,
      status: PaymentStatus.CAPTURED,
      customQuoteRevision: {
        ...payment.customQuoteRevision,
        paymentStatus: 'PAID'
      }
    } as never);
    vi.mocked(prisma.payment.updateMany).mockResolvedValueOnce({ count: 0 } as never);

    const result = await settleCustomQuotePayment(
      'payment-quote-1',
      PaymentStatus.CAPTURED,
      30000,
      { webhookEvent: 'payment.captured' }
    );

    expect(result).toEqual({ duplicateCapture: false, mismatch: false });
    expect(raiseOpsAlert).not.toHaveBeenCalled();
    expect(tx.booking.update).not.toHaveBeenCalled();
    expect(tx.invoice.update).not.toHaveBeenCalled();
  });

  it('records full quote refunds and prevents refunded extra work from remaining approved', async () => {
    await settleCustomQuotePayment('payment-quote-1', PaymentStatus.REFUNDED, undefined, { refundAmount: 30000 });
    expect(tx.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'payment-quote-1', status: { in: [PaymentStatus.PENDING, PaymentStatus.CAPTURED, PaymentStatus.REFUNDED] } },
      data: expect.objectContaining({ status: PaymentStatus.REFUNDED })
    }));
    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ paymentStatus: { in: ['PAID', 'PAYMENT_PENDING', 'PAYMENT_FAILED', 'PARTIALLY_REFUNDED'] } }),
      data: { paymentStatus: 'REFUNDED' }
    }));
  });

  it.each([
    'amountMismatch',
    'duplicateQuoteCapture',
    'capturedAfterBookingClosed',
    'capturedAfterQuoteRefund'
  ])('records a refund for an extra capture marked %s without changing the revision ledger', async (flag) => {
    const extraCapturePayment = {
      ...payment,
      status: PaymentStatus.CAPTURED,
      notes: { [flag]: true }
    };
    vi.mocked(prisma.payment.findUnique).mockResolvedValue(extraCapturePayment as never);
    tx.payment.findUnique.mockResolvedValue(extraCapturePayment);

    await expect(
      settleCustomQuotePayment('payment-quote-1', PaymentStatus.REFUNDED, undefined, {
        refundAmount: 30000,
        refundId: `refund-${flag}`
      })
    ).resolves.toEqual({
      status: PaymentStatus.REFUNDED,
      fullyRefunded: true,
      extraCaptureRefund: true
    });

    expect(tx.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ id: 'payment-quote-1' }),
      data: expect.objectContaining({
        status: PaymentStatus.REFUNDED,
        notes: expect.objectContaining({ customQuoteRefundedAmountPaise: 30000 })
      })
    }));
    expect(tx.customQuoteRevision.updateMany).not.toHaveBeenCalled();
  });

  it('blocks quote work when the quote payment is partially refunded', async () => {
    await settleCustomQuotePayment('payment-quote-1', PaymentStatus.REFUNDED, undefined, { refundAmount: 10000 });
    expect(tx.customQuoteRevision.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: { paymentStatus: 'PARTIALLY_REFUNDED' }
    }));
    expect(tx.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.not.objectContaining({ status: PaymentStatus.REFUNDED })
    }));
  });
});
