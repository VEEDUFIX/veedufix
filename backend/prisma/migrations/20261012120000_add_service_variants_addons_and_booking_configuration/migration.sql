ALTER TABLE "BookingService"
ADD COLUMN "configuration" JSONB;

CREATE TABLE "ServiceVariant" (
  "id" TEXT NOT NULL,
  "serviceId" TEXT NOT NULL,
  "name" VARCHAR(120) NOT NULL,
  "description" VARCHAR(1000),
  "imageUrl" VARCHAR(2048),
  "price" DECIMAL(12, 2) NOT NULL,
  "originalPrice" DECIMAL(12, 2),
  "estimatedDurationMins" INTEGER,
  "isAvailable" BOOLEAN NOT NULL DEFAULT true,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ServiceVariant_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ServiceVariant_serviceId_isAvailable_sortOrder_idx"
ON "ServiceVariant"("serviceId", "isAvailable", "sortOrder");

ALTER TABLE "ServiceVariant"
ADD CONSTRAINT "ServiceVariant_serviceId_fkey"
FOREIGN KEY ("serviceId") REFERENCES "Service"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ServiceAddon" (
  "id" TEXT NOT NULL,
  "serviceId" TEXT NOT NULL,
  "name" VARCHAR(120) NOT NULL,
  "description" VARCHAR(1000),
  "imageUrl" VARCHAR(2048),
  "price" DECIMAL(12, 2) NOT NULL,
  "estimatedDurationMins" INTEGER,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ServiceAddon_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ServiceAddon_serviceId_isActive_sortOrder_idx"
ON "ServiceAddon"("serviceId", "isActive", "sortOrder");

ALTER TABLE "ServiceAddon"
ADD CONSTRAINT "ServiceAddon_serviceId_fkey"
FOREIGN KEY ("serviceId") REFERENCES "Service"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
