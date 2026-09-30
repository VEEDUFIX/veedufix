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
  exportFinancialReconciliationCsv,
  financialYearRange,
  currentFinancialYearRange,
  parseDateRange
} from '../modules/tax-summary/tax-summary.service.js';
import { prisma } from '../lib/prisma.js';

describe('Tax Summary Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('financialYearRange', () => {
    it('parses financial year correctly', () => {
      const { startDate, endDate } = financialYearRange('2023-24');
      expect(startDate.toISOString()).toBe('2023-03-31T18:30:00.000Z');
      expect(endDate.toISOString()).toBe('2024-03-31T18:29:59.999Z');
    });

    it('parses full financial year correctly', () => {
      const { startDate, endDate } = financialYearRange('2023-2024');
      expect(startDate.toISOString()).toBe('2023-03-31T18:30:00.000Z');
      expect(endDate.toISOString()).toBe('2024-03-31T18:29:59.999Z');
    });

    it('throws error for invalid year', () => {
      expect(() => financialYearRange('2023-25')).toThrow('Invalid financial year');
    });

    it('uses Indian date boundaries independent of server timezone', () => {
      const { startDate, endDate } = parseDateRange('2026-04-01', '2026-04-01');
      expect(startDate.toISOString()).toBe('2026-03-31T18:30:00.000Z');
      expect(endDate.toISOString()).toBe('2026-04-01T18:29:59.999Z');
    });

    it('rejects invalid and reversed date ranges', () => {
      expect(() => parseDateRange('2026-02-30', '2026-03-01')).toThrow('Invalid date range');
      expect(() => parseDateRange('2026-04-02', '2026-04-01')).toThrow('Invalid date range');
    });

    it('selects the current financial year using India-local time', () => {
      const beforeIndiaMidnight = currentFinancialYearRange(new Date('2026-03-31T18:29:00Z'));
      const afterIndiaMidnight = currentFinancialYearRange(new Date('2026-03-31T18:31:00Z'));
      expect(beforeIndiaMidnight.startDate.toISOString()).toBe('2025-03-31T18:30:00.000Z');
      expect(afterIndiaMidnight.startDate.toISOString()).toBe('2026-03-31T18:30:00.000Z');
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

    it('uses discounted line taxable values so headline and SAC totals reconcile', async () => {
      vi.mocked(prisma.invoice.findMany).mockResolvedValue([
        {
          id: 'discounted-invoice',
          issuedAt: new Date('2023-05-03T10:00:00Z'),
          subtotalAmount: new Prisma.Decimal(1000),
          discountAmount: new Prisma.Decimal(100),
          totalGstAmount: new Prisma.Decimal(162),
          lineItems: [
            { sacCode: '9987', basePrice: 450, gstAmount: 81 },
            { sacCode: '9987', basePrice: 450, gstAmount: 81 }
          ]
        }
      ] as any);

      const res = await getGstSummary('2023-05-01', '2023-05-31');
      expect(res.totalTaxableValue).toBe(900);
      expect(res.breakdown[0].taxableValue).toBe(900);
      expect(res.totalGstCollected).toBe(162);
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
          customerName: '=2+2',
          subtotalAmount: new Prisma.Decimal(100),
          discountAmount: new Prisma.Decimal(0),
          totalGstAmount: new Prisma.Decimal(18),
          grandTotal: new Prisma.Decimal(118),
          booking: {
            code: 'B-123',
            status: 'COMPLETED',
            worker: { fullName: 'Worker Joe', user: { name: 'Worker Joe' } }
          },
          lineItems: [
            { description: 'Plumbing', sacCode: '9987', quantity: 1, basePrice: 50, gstAmount: 9, total: 59 },
            { description: 'Repair', sacCode: '9987', quantity: 1, basePrice: 50, gstAmount: 9, total: 59 }
          ]
        }
      ] as any);

      const csv = await exportTaxInvoicesCsv('2023-05-01', '2023-05-31');
      expect(csv).toContain('invoice_number,booking_code');
      const rows = csv.split('\n');
      expect(rows).toHaveLength(3);
      expect(rows[1]).toContain(",'=2+2,");
      expect(rows[1]).toContain('Plumbing,9987,1,50,9,59,100,0,18,118');
      expect(rows[2]).toContain('Repair,9987,1,50,9,59,,,,');
      expect(rows[0].split(',')).toHaveLength(rows[1].split(',').length);
    });
  });

  describe('exportFinancialReconciliationCsv', () => {
    it('matches invoice totals with the linked payout and exports masked-safe identifiers only', async () => {
      vi.mocked(prisma.invoice.findMany).mockResolvedValue([
        {
          invoiceNumber: 'VDX-2026-0001',
          issuedAt: new Date('2026-09-15T10:00:00Z'),
          subtotalAmount: new Prisma.Decimal(1000),
          discountAmount: new Prisma.Decimal(100),
          totalGstAmount: new Prisma.Decimal(162),
          grandTotal: new Prisma.Decimal(1062),
          booking: {
            code: 'VF-1001',
            status: 'COMPLETED',
            payout: {
              amount: new Prisma.Decimal(780),
              commissionAmount: new Prisma.Decimal(120),
              status: 'success',
              createdAt: new Date('2026-09-15T11:00:00Z'),
              razorpayPayoutId: 'pout_123'
            }
          }
        }
      ] as any);

      const csv = await exportFinancialReconciliationCsv('2026-09-01', '2026-09-30');
      expect(csv).toContain('taxable_value_after_discount,invoice_discount,gst_collected');
      expect(csv).toContain('900,100,162,1062,120,780,success');
      expect(csv).toContain('pout_123');
    });
  });
});
