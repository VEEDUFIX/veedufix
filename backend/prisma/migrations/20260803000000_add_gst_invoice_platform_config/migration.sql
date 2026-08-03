-- Add GST fields to services and booking line items
ALTER TABLE "Service"
ADD COLUMN "gstRate" DECIMAL(5,2) NOT NULL DEFAULT 18.00,
ADD COLUMN "sacCode" TEXT;

ALTER TABLE "ServiceArea"
ADD COLUMN "pincodeRangeStart" TEXT,
ADD COLUMN "pincodeRangeEnd" TEXT;

ALTER TABLE "BookingService"
ADD COLUMN "gstRate" DECIMAL(5,2) NOT NULL DEFAULT 18.00,
ADD COLUMN "gstAmount" DECIMAL(12,2) NOT NULL DEFAULT 0.0,
ADD COLUMN "sacCode" TEXT NOT NULL DEFAULT 'PENDING';

-- Platform configuration used for GST invoice generation
CREATE TABLE "PlatformConfig" (
    "key" TEXT NOT NULL DEFAULT 'primary',
    "gstin" TEXT,
    "legalBusinessName" TEXT,
    "registeredAddress" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PlatformConfig_pkey" PRIMARY KEY ("key")
);

-- Invoice numbering sequence used by the invoice service
CREATE TABLE "InvoiceSequence" (
    "key" TEXT NOT NULL DEFAULT 'invoice',
    "currentValue" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "InvoiceSequence_pkey" PRIMARY KEY ("key")
);

-- Stored invoices for completed bookings
CREATE TABLE "Invoice" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "invoiceNumber" TEXT NOT NULL,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "platformGstin" TEXT NOT NULL,
    "customerName" TEXT NOT NULL,
    "customerGstin" TEXT,
    "lineItems" JSONB NOT NULL,
    "subtotalAmount" DECIMAL(12,2) NOT NULL,
    "totalGstAmount" DECIMAL(12,2) NOT NULL,
    "discountAmount" DECIMAL(12,2) NOT NULL,
    "grandTotal" DECIMAL(12,2) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Invoice_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "Invoice_bookingId_key" ON "Invoice"("bookingId");
CREATE UNIQUE INDEX "Invoice_invoiceNumber_key" ON "Invoice"("invoiceNumber");

ALTER TABLE "Invoice"
ADD CONSTRAINT "Invoice_bookingId_fkey"
FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;
