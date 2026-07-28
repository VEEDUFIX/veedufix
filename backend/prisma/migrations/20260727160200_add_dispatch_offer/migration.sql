-- CreateTable
CREATE TABLE "DispatchOffer" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "workerId" TEXT NOT NULL,
    "rank" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "offeredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "respondedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DispatchOffer_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DispatchOffer_bookingId_idx" ON "DispatchOffer"("bookingId");

-- CreateIndex
CREATE INDEX "DispatchOffer_status_expiresAt_idx" ON "DispatchOffer"("status", "expiresAt");

-- AddForeignKey
ALTER TABLE "DispatchOffer" ADD CONSTRAINT "DispatchOffer_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
