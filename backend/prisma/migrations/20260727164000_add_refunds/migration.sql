-- CreateTable
CREATE TABLE "Refund" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "disputeId" TEXT,
    "amount" DOUBLE PRECISION NOT NULL,
    "reason" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "razorpayRefundId" TEXT,
    "failureReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Refund_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Refund_bookingId_idx" ON "Refund"("bookingId");

-- CreateIndex
CREATE INDEX "Refund_status_createdAt_idx" ON "Refund"("status", "createdAt");

-- CreateIndex
CREATE INDEX "Refund_disputeId_idx" ON "Refund"("disputeId");

-- AddForeignKey
ALTER TABLE "Refund" ADD CONSTRAINT "Refund_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddColumn
ALTER TABLE "Dispute" ADD COLUMN "refundId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "Dispute_refundId_key" ON "Dispute"("refundId");

-- AddForeignKey
ALTER TABLE "Dispute" ADD CONSTRAINT "Dispute_refundId_fkey" FOREIGN KEY ("refundId") REFERENCES "Refund"("id") ON DELETE SET NULL ON UPDATE CASCADE;
