ALTER TABLE "Service"
ADD COLUMN "publicationStatus" TEXT NOT NULL DEFAULT 'PUBLISHED',
ADD COLUMN "publishStartsAt" TIMESTAMP(3),
ADD COLUMN "publishEndsAt" TIMESTAMP(3);

CREATE INDEX "Service_publicationStatus_publishStartsAt_publishEndsAt_idx"
ON "Service"("publicationStatus", "publishStartsAt", "publishEndsAt");

CREATE TABLE "ServiceAreaService" (
  "serviceId" TEXT NOT NULL,
  "serviceAreaId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ServiceAreaService_pkey" PRIMARY KEY ("serviceId", "serviceAreaId")
);

CREATE INDEX "ServiceAreaService_serviceAreaId_serviceId_idx"
ON "ServiceAreaService"("serviceAreaId", "serviceId");

ALTER TABLE "ServiceAreaService"
ADD CONSTRAINT "ServiceAreaService_serviceId_fkey"
FOREIGN KEY ("serviceId") REFERENCES "Service"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ServiceAreaService"
ADD CONSTRAINT "ServiceAreaService_serviceAreaId_fkey"
FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
