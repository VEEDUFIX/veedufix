import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────
vi.mock('../lib/prisma.js', () => ({
  prisma: {
    invoice: { findMany: vi.fn() },
    payout: { findMany: vi.fn() },
  }
}));

// ─── Imports ──────────────────────────────────────────────────────────────────
import {
  getGstSummary,
  getRevenueSummary,
  getAnnualSummary,
  exportTaxInvoicesCsv,
  financialYearRange
} from '../modules/tax-summary/tax-summary.service.js';
import { prisma } from '../lib/prisma.js';

describe('Tax Summary Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('financialYearRange', () => {
    it('parses financial year correctly', () => {
      const { startDate, endDate } = financialYearRange('2023-24');
      expect(startDate.getFullYear()).toBe(2023);
      expect(startDate.getMonth()).toBe(3); // April
      expect(startDate.getDate()).toBe(1);
      
      expect(endDate.getFullYear()).toBe(2024);
      expect(endDate.getMonth()).toBe(2); // March
      expect(endDate.getDate()).toBe(31);
    });

    it('parses full financial year correctly', () => {
      const { startDate, endDate } = financialYearRange('2023-2024');
      expect(startDate.getFullYear()).toBe(2023);
      expect(startDate.getMonth()).toBe(3);
      expect(startDate.getDate()).toBe(1);
      
      expect(endDate.getFullYear()).toBe(2024);
      expect(endDate.getMonth()).toBe(2);
      expect(endDate.getDate()).toBe(31);
    });

    it('throws error for invalid year', () => {
      expect(() => financialYearRange('2023-25')).toThrow('Invalid financial year');
    });
  });

  describe('getGstSummary', () => {
    it('calculates GST summary from invoices', async () => {
      vi.mocked(prisma.invoice.findMany).mockResolvedValue([
        {
          id: 'inv1',
          issuedAt: new Date('2023-05-01T10:00:00Z'),
          subtotalAmount: new Prisma.Decimal(100),
          totalGstAmount: new Prisma.Decimal(18),
          lineItems: [
            { sacCode: '9987', basePrice: 100, gstAmount: 18 }
          ]
        },
        {
          id: 'inv2',
          issuedAt: new Date('2023-05-02T10:00:00Z'),
          subtotalAmount: new Prisma.Decimal(200),
          totalGstAmount: new Prisma.Decimal(36),
          lineItems: [
            { sacCode: '9987', basePrice: 200, gstAmount: 36 }
          ]
        }
      ] as any);

      const res = await getGstSummary('2023-05-01', '2023-05-31');
      expect(res.invoiceCount).toBe(2);
      expect(res.totalTaxableValue).toBe(300);
      expect(res.totalGstCollected).toBe(54);
      expect(res.breakdown[0].sacCode).toBe('9987');
      expect(res.breakdown[0].taxableValue).toBe(300);
      expect(res.breakdown[0].gstAmount).toBe(54);
      expect(res.breakdown[0].invoiceCount).toBe(2);
    });
  });

  describe('getRevenueSummary', () => {
    it('calculates revenue summary from payouts', async () => {
      vi.mocked(prisma.invoice.findMany).mockResolvedValue([
        {
          issuedAt: new Date('2023-05-01T10:00:00Z'),
          subtotalAmount: new Prisma.Decimal(100),
          totalGstAmount: new Prisma.Decimal(18),
        }
      ] as any);
      vi.mocked(prisma.payout.findMany).mockResolvedValue([
        {
          amount: new Prisma.Decimal(80),
          commissionAmount: new Prisma.Decimal(20),
          createdAt: new Date('2023-05-01T11:00:00Z'),
          status: 'success'
        },
        {
          amount: new Prisma.Decimal(80), // should be ignored as failed
          commissionAmount: new Prisma.Decimal(20),
          createdAt: new Date('2023-05-01T12:00:00Z'),
          status: 'failed'
        }
      ] as any);

      const res = await getRevenueSummary('2023-05-01', '2023-05-31');
      expect(res.totalGstLiability).toBe(18);
      expect(res.platformCommissionEarned).toBe(20);
      expect(res.totalWorkerPayouts).toBe(80);
      expect(res.payoutCount).toBe(1);
    });
  });

  describe('exportTaxInvoicesCsv', () => {
    it('exports CSV of invoices', async () => {
      vi.mocked(prisma.invoice.findMany).mockResolvedValue([
        {
          invoiceNumber: 'VDX-2023-0001',
          issuedAt: new Date('2023-05-01T10:00:00Z'),
          customerName: 'John Doe',
          subtotalAmount: new Prisma.Decimal(100),
          totalGstAmount: new Prisma.Decimal(18),
          grandTotal: new Prisma.Decimal(118),
          booking: {
            code: 'B-123',
            status: 'COMPLETED',
            worker: { fullName: 'Worker Joe', user: { name: 'Worker Joe' } }
          },
          lineItems: [
            { description: 'Plumbing', sacCode: '9987', quantity: 1, basePrice: 100, gstAmount: 18, total: 118 }
          ]
        }
      ] as any);

      const csv = await exportTaxInvoicesCsv('2023-05-01', '2023-05-31');
      expect(csv).toContain('invoice_number,booking_code');
      expect(csv).toContain('VDX-2023-0001,B-123,2023-05-01T10:00:00.000Z,John Doe,Worker Joe,COMPLETED,Plumbing,9987,1,100,18,118,100,18,118');
    });
  });
});
