CREATE TABLE "BookingDiagnosticPhoto" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT,
    "uploadedById" TEXT,
    "clientUploadId" TEXT NOT NULL,
    "publicId" TEXT NOT NULL,
    "format" VARCHAR(16) NOT NULL,
    "bytes" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3),
    CONSTRAINT "BookingDiagnosticPhoto_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "BookingDiagnosticPhoto_publicId_key" ON "BookingDiagnosticPhoto"("publicId");
CREATE UNIQUE INDEX "BookingDiagnosticPhoto_uploadedById_clientUploadId_key" ON "BookingDiagnosticPhoto"("uploadedById", "clientUploadId");
CREATE INDEX "BookingDiagnosticPhoto_bookingId_createdAt_idx" ON "BookingDiagnosticPhoto"("bookingId", "createdAt");
CREATE INDEX "BookingDiagnosticPhoto_uploadedById_bookingId_expiresAt_idx" ON "BookingDiagnosticPhoto"("uploadedById", "bookingId", "expiresAt");

ALTER TABLE "BookingDiagnosticPhoto" ADD CONSTRAINT "BookingDiagnosticPhoto_bookingId_fkey"
  FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "BookingDiagnosticPhoto" ADD CONSTRAINT "BookingDiagnosticPhoto_uploadedById_fkey"
  FOREIGN KEY ("uploadedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;