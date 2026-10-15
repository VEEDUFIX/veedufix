CREATE TABLE "ServiceAreaPincode" (
    "id" TEXT NOT NULL,
    "serviceAreaId" TEXT NOT NULL,
    "pincode" VARCHAR(6) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ServiceAreaPincode_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ServiceAreaPincode_serviceAreaId_pincode_key"
ON "ServiceAreaPincode"("serviceAreaId", "pincode");

CREATE INDEX "ServiceAreaPincode_pincode_idx"
ON "ServiceAreaPincode"("pincode");

ALTER TABLE "ServiceAreaPincode"
ADD CONSTRAINT "ServiceAreaPincode_serviceAreaId_fkey"
FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
