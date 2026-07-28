-- CreateTable
CREATE TABLE "SavedAddress" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "addressLine1" TEXT NOT NULL,
    "addressLine2" TEXT,
    "landmark" TEXT,
    "city" TEXT NOT NULL,
    "pincode" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SavedAddress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkerAvailability" (
    "id" TEXT NOT NULL,
    "workerId" TEXT NOT NULL,
    "dayOfWeek" INTEGER NOT NULL,
    "startTime" TEXT NOT NULL,
    "endTime" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WorkerAvailability_pkey" PRIMARY KEY ("id")
);

-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "bookingType" TEXT NOT NULL DEFAULT 'instant';
ALTER TABLE "Booking" ADD COLUMN     "scheduledFor" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "Booking_scheduledFor_idx" ON "Booking"("scheduledFor");

-- CreateIndex
CREATE INDEX "SavedAddress_userId_isDefault_createdAt_idx" ON "SavedAddress"("userId", "isDefault", "createdAt");

-- CreateIndex
CREATE INDEX "WorkerAvailability_workerId_dayOfWeek_idx" ON "WorkerAvailability"("workerId", "dayOfWeek");

-- AddForeignKey
ALTER TABLE "SavedAddress" ADD CONSTRAINT "SavedAddress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkerAvailability" ADD CONSTRAINT "WorkerAvailability_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "WorkerProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
