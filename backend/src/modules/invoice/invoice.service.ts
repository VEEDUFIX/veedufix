import { BookingStatus, PaymentStatus, Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { allocateProportionalShares, reverseInclusiveTax, roundMoney } from "../../lib/gst.js";

export type InvoiceLineItemDto = {
  description: string;
  sacCode: string;
  quantity: number;
  unitPrice: number;
  basePrice: number;
  gstRate: number;
  gstAmount: number;
  total: number;
};

export type InvoiceDto = {
  id: string;
  bookingId: string;
  bookingCode: string;
  bookingStatus: string;
  invoiceNumber: string;
  issuedAt: string;
  platformGstin: string;
  legalBusinessName: string;
  registeredAddress: string;
  customerName: string;
  customerGstin: string | null;
  lineItems: InvoiceLineItemDto[];
  subtotalAmount: number;
  totalGstAmount: number;
  discountAmount: number;
  grandTotal: number;
};

type InvoiceRecord = Prisma.InvoiceGetPayload<{}>;

function decimalToNumber(value: Prisma.Decimal | number | string): number {
  return value instanceof Prisma.Decimal ? value.toNumber() : Number(value);
}

function serializeLineItems(lineItems: Array<Record<string, unknown>>): InvoiceLineItemDto[] {
  return lineItems.map((item) => ({
    description: String(item.description ?? "Service"),
    sacCode: String(item.sacCode ?? "PENDING"),
    quantity: Number(item.quantity ?? 1),
    unitPrice: Number(item.unitPrice ?? 0),
    basePrice: Number(item.basePrice ?? 0),
    gstRate: Number(item.gstRate ?? 0),
    gstAmount: Number(item.gstAmount ?? 0),
    total: Number(item.total ?? 0)
  }));
}

function serializeInvoice(invoice: InvoiceRecord & {
  bookingCode?: string;
  bookingStatus?: string;
  legalBusinessName?: string;
  registeredAddress?: string;
}): InvoiceDto {
  const lineItems = Array.isArray(invoice.lineItems)
    ? serializeLineItems(invoice.lineItems as Array<Record<string, unknown>>)
    : [];

  return {
    id: invoice.id,
    bookingId: invoice.bookingId,
    bookingCode: invoice.bookingCode ?? "",
    bookingStatus: invoice.bookingStatus ?? "",
    invoiceNumber: invoice.invoiceNumber,
    issuedAt: invoice.issuedAt.toISOString(),
    platformGstin: invoice.platformGstin,
    legalBusinessName: invoice.legalBusinessName ?? "",
    registeredAddress: invoice.registeredAddress ?? "",
    customerName: invoice.customerName,
    customerGstin: invoice.customerGstin ?? null,
    lineItems,
    subtotalAmount: decimalToNumber(invoice.subtotalAmount),
    totalGstAmount: decimalToNumber(invoice.totalGstAmount),
    discountAmount: decimalToNumber(invoice.discountAmount),
    grandTotal: decimalToNumber(invoice.grandTotal)
  };
}

export async function generateInvoiceForBooking(bookingId: string): Promise<InvoiceDto> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      customer: true,
      services: {
        include: {
          service: true,
          serviceSubcategory: true
        },
        orderBy: {
          createdAt: "asc"
        }
      },
      payments: true
    }
  });

  if (!booking) {
    throw new Error("Booking not found");
  }

  const hasCapturedPayment = booking.payments.some((payment) => payment.status === PaymentStatus.CAPTURED);
  if (!hasCapturedPayment) {
    throw new Error("Invoice can only be generated after payment capture");
  }

  const nonBillableStatuses: BookingStatus[] = [
    BookingStatus.PENDING,
    BookingStatus.CANCELLED,
    BookingStatus.CANCELLED_MANUAL,
    BookingStatus.CANCELLED_NO_SHOW,
    BookingStatus.REFUNDED
  ];

  if (nonBillableStatuses.includes(booking.status)) {
    throw new Error("Booking is not eligible for invoicing");
  }

  const platformConfig = await prisma.platformConfig.findUnique({
    where: { key: "primary" }
  });

  if (!platformConfig?.gstin || !platformConfig.legalBusinessName || !platformConfig.registeredAddress) {
    throw new Error("Platform GST configuration is incomplete");
  }

  const platformGstin = platformConfig.gstin;

  const existingInvoice = await prisma.invoice.findUnique({
    where: { bookingId: booking.id }
  });

  if (existingInvoice) {
    const invoiceCode = booking.code;
    return serializeInvoice({
      ...existingInvoice,
      bookingCode: invoiceCode,
      bookingStatus: booking.status,
      legalBusinessName: platformConfig.legalBusinessName,
      registeredAddress: platformConfig.registeredAddress
    });
  }

  if (booking.services.length === 0) {
    throw new Error("Booking has no services to invoice");
  }

  const subtotalAmount = roundMoney(booking.subtotalAmount);
  const discountAmount = roundMoney(booking.discountAmount);
  const grandTotal = roundMoney(booking.totalAmount);
  const totalGstAmount = roundMoney(booking.taxAmount);
  const discountShares = allocateProportionalShares(
    discountAmount,
    booking.services.map((service) => service.totalPrice)
  );

  const invoiceLineItems = booking.services.map((service, index) => {
    const discountShare = discountShares[index] ?? new Prisma.Decimal(0);
    const netTotal = roundMoney(service.totalPrice.sub(discountShare));
    const storedGstRate = service.gstRate instanceof Prisma.Decimal ? service.gstRate : new Prisma.Decimal(service.gstRate ?? 0);
    const reverseTax = reverseInclusiveTax(netTotal, storedGstRate);
    const gstAmount = index === booking.services.length - 1
      ? roundMoney(totalGstAmount.sub(
          booking.services.slice(0, index).reduce((sum, previous) => sum.add(previous.gstAmount), new Prisma.Decimal(0))
        ))
      : reverseTax.gstAmount;
    const basePrice = roundMoney(netTotal.sub(gstAmount));

    return {
      description:
        service.service?.name ??
        service.serviceSubcategory?.name ??
        "Service",
      sacCode: service.sacCode ?? service.service?.sacCode ?? "PENDING",
      quantity: service.quantity,
      unitPrice: decimalToNumber(service.unitPrice),
      basePrice: decimalToNumber(basePrice),
      gstRate: decimalToNumber(storedGstRate),
      gstAmount: decimalToNumber(gstAmount),
      total: decimalToNumber(netTotal)
    };
  });

  await prisma.$transaction(async (tx) => {
    const sequence = await tx.invoiceSequence.upsert({
      where: { key: "invoice" },
      update: {
        currentValue: {
          increment: 1
        }
      },
      create: {
        key: "invoice",
        currentValue: 1
      }
    });

    const issuedAt = new Date();
    const sequenceNumber = String(sequence.currentValue).padStart(6, "0");
    const generatedInvoiceNumber = `VDX-${issuedAt.getFullYear()}-${sequenceNumber}`;

    try {
      await tx.invoice.create({
        data: {
          bookingId: booking.id,
          invoiceNumber: generatedInvoiceNumber,
          issuedAt,
          platformGstin,
          customerName: booking.customer.name ?? "Customer",
          customerGstin: null,
          lineItems: invoiceLineItems as Prisma.InputJsonValue,
          subtotalAmount,
          totalGstAmount,
          discountAmount,
          grandTotal
        }
      });
    } catch (error) {
      const existing = await tx.invoice.findUnique({
        where: { bookingId: booking.id }
      });

      if (existing) {
        return;
      }

      throw error;
    }
  });

  const invoice = await prisma.invoice.findUnique({
    where: { bookingId: booking.id }
  });

  if (!invoice) {
    throw new Error("Invoice creation failed");
  }

  return serializeInvoice({
    ...invoice,
    bookingCode: booking.code,
    bookingStatus: booking.status,
    legalBusinessName: platformConfig.legalBusinessName,
    registeredAddress: platformConfig.registeredAddress
  });
}

export async function getInvoiceForBooking(bookingId: string): Promise<InvoiceDto | null> {
  const invoice = await prisma.invoice.findUnique({
    where: { bookingId },
    include: {
      booking: {
        select: {
          code: true,
          status: true
        }
      }
    }
  });

  if (!invoice) {
    return null;
  }

  const platformConfig = await prisma.platformConfig.findUnique({
    where: { key: "primary" }
  });

  return serializeInvoice({
    ...invoice,
    bookingCode: invoice.booking.code,
    bookingStatus: invoice.booking.status,
    legalBusinessName: platformConfig?.legalBusinessName ?? "",
    registeredAddress: platformConfig?.registeredAddress ?? ""
  });
}
