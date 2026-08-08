import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma, PaymentStatus, BookingStatus } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: vi.fn() },
    platformConfig: { findUnique: vi.fn() },
    invoice: { findUnique: vi.fn(), create: vi.fn() },
    $transaction: vi.fn((cb) => cb(prismaMockTx)),
  },
}));

const prismaMockTx = {
  invoiceSequence: { upsert: vi.fn() },
  invoice: { create: vi.fn(), findUnique: vi.fn() },
};

// ─── Imports ──────────────────────────────────────────────────────────────────

import { generateInvoiceForBooking, getInvoiceForBooking } from '../modules/invoice/invoice.service.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';

describe('Invoice Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('generateInvoiceForBooking', () => {
    it('throws AppError.notFound if booking not found', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(null);
      await expect(generateInvoiceForBooking('invalid')).rejects.toSatisfy(
        (err: any) => err instanceof AppError && err.statusCode === 404
      );
    });

    it('throws conflict if no captured payment', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1',
        payments: [{ status: PaymentStatus.PENDING }]
      } as any);
      
      await expect(generateInvoiceForBooking('b1')).rejects.toSatisfy(
        (err: any) => err instanceof AppError && err.statusCode === 409
      );
    });

    it('throws conflict if booking is not eligible', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1',
        status: BookingStatus.CANCELLED,
        payments: [{ status: PaymentStatus.CAPTURED }]
      } as any);
      
      await expect(generateInvoiceForBooking('b1')).rejects.toSatisfy(
        (err: any) => err instanceof AppError && err.statusCode === 409
      );
    });

    it('returns existing invoice if already exists', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1', status: BookingStatus.COMPLETED,
        payments: [{ status: PaymentStatus.CAPTURED }]
      } as any);

      vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue({
        gstin: 'GST123', legalBusinessName: 'Test Inc', registeredAddress: '123 Test St'
      } as any);

      vi.mocked(prisma.invoice.findUnique).mockResolvedValue({
        id: 'inv1', invoiceNumber: 'VDX-2024-000001', issuedAt: new Date(),
        subtotalAmount: new Prisma.Decimal(100), totalGstAmount: new Prisma.Decimal(18),
        discountAmount: new Prisma.Decimal(0), grandTotal: new Prisma.Decimal(118)
      } as any);

      const res = await generateInvoiceForBooking('b1');
      expect(res.invoiceNumber).toBe('VDX-2024-000001');
      expect(prisma.invoice.create).not.toHaveBeenCalled();
    });

    it('generates a new invoice', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1', status: BookingStatus.COMPLETED,
        customer: { name: 'Test Customer' },
        subtotalAmount: new Prisma.Decimal(100),
        taxAmount: new Prisma.Decimal(18),
        discountAmount: new Prisma.Decimal(0),
        totalAmount: new Prisma.Decimal(118),
        payments: [{ status: PaymentStatus.CAPTURED }],
        services: [{
          quantity: 1, unitPrice: new Prisma.Decimal(100),
          totalPrice: new Prisma.Decimal(118), gstRate: new Prisma.Decimal(18),
          service: { name: 'AC Cleaning', sacCode: '9987' }
        }]
      } as any);

      vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue({
        gstin: 'GST123', legalBusinessName: 'Test Inc', registeredAddress: '123 Test St'
      } as any);

      // findUnique returns null the first time (checking for existing)
      // then returns the new invoice at the end
      let callCount = 0;
      vi.mocked(prisma.invoice.findUnique).mockImplementation((async () => {
        callCount++;
        if (callCount === 1) return null;
        return {
          id: 'inv2', invoiceNumber: 'VDX-2024-000002', issuedAt: new Date(),
          subtotalAmount: new Prisma.Decimal(100), totalGstAmount: new Prisma.Decimal(18),
          discountAmount: new Prisma.Decimal(0), grandTotal: new Prisma.Decimal(118)
        };
      }) as any);

      prismaMockTx.invoiceSequence.upsert.mockResolvedValue({ currentValue: 2 } as any);

      const res = await generateInvoiceForBooking('b1');
      expect(res.invoiceNumber).toBe('VDX-2024-000002');
      expect(prismaMockTx.invoice.create).toHaveBeenCalled();
    });
  });

  describe('getInvoiceForBooking', () => {
    it('returns null if not found', async () => {
      vi.mocked(prisma.invoice.findUnique).mockResolvedValue(null);
      const res = await getInvoiceForBooking('b1');
      expect(res).toBeNull();
    });

    it('returns serialized invoice if found', async () => {
      vi.mocked(prisma.invoice.findUnique).mockResolvedValue({
        id: 'inv1', invoiceNumber: 'VDX-2024-000001', issuedAt: new Date(),
        subtotalAmount: new Prisma.Decimal(100), totalGstAmount: new Prisma.Decimal(18),
        discountAmount: new Prisma.Decimal(0), grandTotal: new Prisma.Decimal(118),
        booking: { code: 'B-1', status: 'COMPLETED' }
      } as any);

      vi.mocked(prisma.platformConfig.findUnique).mockResolvedValue({
        legalBusinessName: 'Test Inc', registeredAddress: '123 Test St'
      } as any);

      const res = await getInvoiceForBooking('b1');
      expect(res!.invoiceNumber).toBe('VDX-2024-000001');
      expect(res!.legalBusinessName).toBe('Test Inc');
    });
  });
});
