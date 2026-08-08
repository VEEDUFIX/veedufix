import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { getCommissionPercent } from "../payout/payout.service.js";

type DateRange = {
  startDate: Date;
  endDate: Date;
};

type InvoiceLineItem = {
  description: string;
  sacCode: string;
  quantity: number;
  unitPrice: number;
  basePrice: number;
  gstRate: number;
  gstAmount: number;
  total: number;
};

type TaxSummaryInvoiceRecord = {
  id: string;
  issuedAt: Date;
  subtotalAmount: Prisma.Decimal | number | string;
  totalGstAmount: Prisma.Decimal | number | string;
  lineItems: unknown;
};

type TaxSummaryRevenueInvoiceRecord = {
  issuedAt: Date;
  totalGstAmount: Prisma.Decimal | number | string;
};

type TaxSummaryPayoutRecord = {
  amount: Prisma.Decimal | number | string;
  commissionAmount: Prisma.Decimal | number | string;
  createdAt: Date;
  status: string;
};

export type TaxSummaryBreakdownItem = {
  sacCode: string;
  taxableValue: number;
  gstAmount: number;
  invoiceCount: number;
};

export type TaxGstSummary = {
  startDate: string;
  endDate: string;
  invoiceCount: number;
  totalTaxableValue: number;
  totalGstCollected: number;
  breakdown: TaxSummaryBreakdownItem[];
};

export type TaxRevenueSummary = {
  startDate: string;
  endDate: string;
  platformCommissionEarned: number;
  totalGstLiability: number;
  totalWorkerPayouts: number;
  payoutCount: number;
};

export type TaxAnnualSummary = {
  financialYear: string;
  periodStart: string;
  periodEnd: string;
  gstSummary: TaxGstSummary;
  revenueSummary: TaxRevenueSummary;
};

function decimalToNumber(value: Prisma.Decimal | number | string | null | undefined): number {
  if (value == null) {
    return 0;
  }

  if (value instanceof Prisma.Decimal) {
    return value.toNumber();
  }

  return Number(value);
}

function roundToTwo(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export function startOfLocalDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

export function endOfLocalDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(23, 59, 59, 999);
  return copy;
}

function addDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

export function parseDateRange(startDate?: string, endDate?: string): DateRange {
  const start = startDate ? new Date(startDate) : new Date();
  const end = endDate ? new Date(endDate) : new Date();

  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    throw AppError.badRequest("Invalid date range");
  }

  return {
    startDate: startOfLocalDay(start),
    endDate: endOfLocalDay(end)
  };
}

export function financialYearRange(financialYear: string): DateRange {
  const match = financialYear.trim().match(/^(\d{4})\s*[-/]\s*(\d{2}|\d{4})$/);
  if (!match) {
    throw AppError.badRequest("Invalid financial year");
  }

  const startYear = Number(match[1]);
  const endPart = match[2];
  const expectedEndYear = Number(String(startYear + 1).slice(-2));
  const parsedEndYear = endPart.length === 2 ? Number(endPart) : Number(endPart.slice(-2));

  if (Number.isNaN(startYear) || Number.isNaN(parsedEndYear) || parsedEndYear !== expectedEndYear) {
    throw AppError.badRequest("Invalid financial year");
  }

  const startDate = new Date(startYear, 3, 1, 0, 0, 0, 0);
  const endDate = new Date(startYear + 1, 2, 31, 23, 59, 59, 999);

  return { startDate, endDate };
}

export function currentFinancialYearRange(now = new Date()): DateRange {
  const year = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
  return financialYearRange(`${year}-${String(year + 1).slice(-2)}`);
}

function escapeCsvValue(value: unknown): string {
  const str = String(value ?? "");
  if (str.includes(",") || str.includes("\"") || str.includes("\n")) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function csvFromRows(headers: string[], rows: (string | number | null | undefined)[][]): string {
  return [headers.map(escapeCsvValue).join(","), ...rows.map((row) => row.map(escapeCsvValue).join(","))].join("\n");
}

function normalizeLineItems(rawLineItems: unknown): InvoiceLineItem[] {
  if (!Array.isArray(rawLineItems)) {
    return [];
  }

  return rawLineItems.map((item) => {
    const record = (item ?? {}) as Record<string, unknown>;
    return {
      description: String(record.description ?? "Service"),
      sacCode: String(record.sacCode ?? "PENDING"),
      quantity: Number(record.quantity ?? 1),
      unitPrice: Number(record.unitPrice ?? 0),
      basePrice: Number(record.basePrice ?? 0),
      gstRate: Number(record.gstRate ?? 0),
      gstAmount: Number(record.gstAmount ?? 0),
      total: Number(record.total ?? 0)
    };
  });
}

function buildGstSummaryFromInvoices(invoices: TaxSummaryInvoiceRecord[]): TaxGstSummary {
  const breakdownMap = new Map<
    string,
    {
      taxableValue: number;
      gstAmount: number;
      invoiceIds: Set<string>;
    }
  >();

  let totalTaxableValue = 0;
  let totalGstCollected = 0;

  for (const invoice of invoices) {
    totalTaxableValue += decimalToNumber(invoice.subtotalAmount);
    totalGstCollected += decimalToNumber(invoice.totalGstAmount);

    for (const lineItem of normalizeLineItems(invoice.lineItems)) {
      const sacCode = lineItem.sacCode || "PENDING";
      const bucket = breakdownMap.get(sacCode) ?? {
        taxableValue: 0,
        gstAmount: 0,
        invoiceIds: new Set<string>()
      };

      bucket.taxableValue += roundToTwo(lineItem.basePrice);
      bucket.gstAmount += roundToTwo(lineItem.gstAmount);
      bucket.invoiceIds.add(invoice.id);
      breakdownMap.set(sacCode, bucket);
    }
  }

  const breakdown = Array.from(breakdownMap.entries())
    .map(([sacCode, values]) => ({
      sacCode,
      taxableValue: roundToTwo(values.taxableValue),
      gstAmount: roundToTwo(values.gstAmount),
      invoiceCount: values.invoiceIds.size
    }))
    .sort((left, right) => right.taxableValue - left.taxableValue || left.sacCode.localeCompare(right.sacCode));

  return {
    startDate: invoices[0]?.issuedAt?.toISOString() ?? "",
    endDate: invoices[invoices.length - 1]?.issuedAt?.toISOString() ?? "",
    invoiceCount: invoices.length,
    totalTaxableValue: roundToTwo(totalTaxableValue),
    totalGstCollected: roundToTwo(totalGstCollected),
    breakdown
  };
}

function buildRevenueSummaryFromRecords(
  invoices: TaxSummaryRevenueInvoiceRecord[],
  payouts: TaxSummaryPayoutRecord[]
): TaxRevenueSummary {
  const totalGstLiability = invoices.reduce((total, invoice) => total + decimalToNumber(invoice.totalGstAmount), 0);
  const successfulPayouts = payouts.filter((payout) => payout.status === "success");
  const platformCommissionEarned = successfulPayouts.reduce(
    (total, payout) => total + decimalToNumber(payout.commissionAmount),
    0
  );
  const totalWorkerPayouts = successfulPayouts.reduce((total, payout) => total + decimalToNumber(payout.amount), 0);

  return {
    startDate: invoices[0]?.issuedAt?.toISOString() ?? payouts[0]?.createdAt?.toISOString() ?? "",
    endDate: invoices[invoices.length - 1]?.issuedAt?.toISOString() ?? payouts[payouts.length - 1]?.createdAt?.toISOString() ?? "",
    platformCommissionEarned: roundToTwo(platformCommissionEarned),
    totalGstLiability: roundToTwo(totalGstLiability),
    totalWorkerPayouts: roundToTwo(totalWorkerPayouts),
    payoutCount: successfulPayouts.length
  };
}

export async function getGstSummary(startDate: string, endDate: string): Promise<TaxGstSummary> {
  const range = parseDateRange(startDate, endDate);

  const invoices = (await prisma.invoice.findMany({
    where: {
      issuedAt: {
        gte: range.startDate,
        lte: range.endDate
      }
    },
    orderBy: { issuedAt: "asc" },
    select: {
      id: true,
      issuedAt: true,
      subtotalAmount: true,
      totalGstAmount: true,
      lineItems: true
    }
  })) as TaxSummaryInvoiceRecord[];

  return buildGstSummaryFromInvoices(invoices);
}

export async function getRevenueSummary(startDate: string, endDate: string): Promise<TaxRevenueSummary> {
  const range = parseDateRange(startDate, endDate);

  const [invoices, payouts] = await Promise.all([
    prisma.invoice.findMany({
      where: {
        issuedAt: {
          gte: range.startDate,
          lte: range.endDate
        }
      },
      orderBy: { issuedAt: "asc" },
      select: {
        subtotalAmount: true,
        totalGstAmount: true,
        issuedAt: true
      }
    }) as Promise<TaxSummaryRevenueInvoiceRecord[]>,
    prisma.payout.findMany({
      where: {
        createdAt: {
          gte: range.startDate,
          lte: range.endDate
        }
      },
      orderBy: { createdAt: "asc" },
      select: {
        amount: true,
        commissionAmount: true,
        createdAt: true,
        status: true
      }
    }) as Promise<TaxSummaryPayoutRecord[]>
  ]);

  return buildRevenueSummaryFromRecords(invoices, payouts);
}

export async function getAnnualSummary(financialYear: string): Promise<TaxAnnualSummary> {
  const range = financialYearRange(financialYear);
  const [gstSummary, revenueSummary] = await Promise.all([
    getGstSummary(range.startDate.toISOString(), range.endDate.toISOString()),
    getRevenueSummary(range.startDate.toISOString(), range.endDate.toISOString())
  ]);

  return {
    financialYear,
    periodStart: range.startDate.toISOString(),
    periodEnd: range.endDate.toISOString(),
    gstSummary,
    revenueSummary
  };
}

export async function exportTaxInvoicesCsv(startDate: string, endDate: string): Promise<string> {
  const range = parseDateRange(startDate, endDate);

  const invoices = await prisma.invoice.findMany({
    where: {
      issuedAt: {
        gte: range.startDate,
        lte: range.endDate
      }
    },
    include: {
      booking: {
        select: {
          code: true,
          status: true,
          worker: {
            select: {
              fullName: true,
              user: {
                select: {
                  name: true
                }
              }
            }
          }
        }
      }
    },
    orderBy: { issuedAt: "asc" }
  });

  const rows: (string | number | null | undefined)[][] = [];

  for (const invoice of invoices) {
    const lineItems = normalizeLineItems(invoice.lineItems);
    if (lineItems.length === 0) {
      rows.push([
        invoice.invoiceNumber,
        invoice.booking.code,
        invoice.issuedAt.toISOString(),
        invoice.customerName,
        invoice.booking.worker?.fullName ?? invoice.booking.worker?.user.name ?? "",
        invoice.booking.status,
        "",
        "",
        "",
        "",
        decimalToNumber(invoice.subtotalAmount),
        decimalToNumber(invoice.totalGstAmount),
        decimalToNumber(invoice.grandTotal)
      ]);
      continue;
    }

    for (const lineItem of lineItems) {
      rows.push([
        invoice.invoiceNumber,
        invoice.booking.code,
        invoice.issuedAt.toISOString(),
        invoice.customerName,
        invoice.booking.worker?.fullName ?? invoice.booking.worker?.user.name ?? "",
        invoice.booking.status,
        lineItem.description,
        lineItem.sacCode,
        lineItem.quantity,
        roundToTwo(lineItem.basePrice),
        roundToTwo(lineItem.gstAmount),
        roundToTwo(lineItem.total),
        decimalToNumber(invoice.subtotalAmount),
        decimalToNumber(invoice.totalGstAmount),
        decimalToNumber(invoice.grandTotal)
      ]);
    }
  }

  return csvFromRows(
    [
      "invoice_number",
      "booking_code",
      "issued_at",
      "customer_name",
      "worker_name",
      "booking_status",
      "line_item_description",
      "sac_code",
      "quantity",
      "taxable_value",
      "gst_amount",
      "line_total",
      "invoice_subtotal",
      "invoice_gst_total",
      "invoice_grand_total"
    ],
    rows
  );
}

export function buildTaxSummarySnapshotForTest(input: {
  invoices: Array<{
    id: string;
    issuedAt: Date;
    subtotalAmount: number;
    totalGstAmount: number;
    lineItems: unknown;
  }>;
  payouts: Array<{
    amount: number;
    commissionAmount: number;
    createdAt: Date;
    status: string;
  }>;
}) {
  return {
    gstSummary: buildGstSummaryFromInvoices(input.invoices),
    revenueSummary: buildRevenueSummaryFromRecords(input.invoices, input.payouts)
  };
}

export function getPlatformCommissionPercentForReference(): number {
  return getCommissionPercent();
}
