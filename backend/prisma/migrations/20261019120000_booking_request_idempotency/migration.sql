ALTER TABLE "Booking"
  ADD COLUMN "clientRequestKey" VARCHAR(120),
  ADD COLUMN "clientRequestHash" VARCHAR(64);

CREATE UNIQUE INDEX "Booking_customerId_clientRequestKey_key"
  ON "Booking"("customerId", "clientRequestKey");
