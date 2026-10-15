-- Add normalized geography, inherited catalog availability, and explicit partner-area links.
-- This migration is additive: legacy city/state/district and worker serviceAreas columns remain
-- available for the application compatibility window.

CREATE TABLE "GeoState" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "GeoState_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "GeoState_name_key" ON "GeoState"("name");

INSERT INTO "GeoState" ("id", "name", "updatedAt")
SELECT md5('veedufix:state:' || normalized."name"), normalized."name", CURRENT_TIMESTAMP
FROM (
  SELECT DISTINCT COALESCE(NULLIF(BTRIM("state"), ''), 'Unknown') AS "name"
  FROM "City"
) normalized
ON CONFLICT ("name") DO NOTHING;

CREATE TABLE "GeoDistrict" (
  "id" TEXT NOT NULL,
  "stateId" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "GeoDistrict_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "GeoDistrict_stateId_name_key" ON "GeoDistrict"("stateId", "name");
CREATE UNIQUE INDEX "GeoDistrict_id_stateId_key" ON "GeoDistrict"("id", "stateId");
CREATE INDEX "GeoDistrict_stateId_name_idx" ON "GeoDistrict"("stateId", "name");
ALTER TABLE "GeoDistrict"
  ADD CONSTRAINT "GeoDistrict_stateId_fkey"
  FOREIGN KEY ("stateId") REFERENCES "GeoState"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

INSERT INTO "GeoDistrict" ("id", "stateId", "name", "updatedAt")
SELECT md5('veedufix:district:' || state_row."id" || ':' || normalized."name"),
       state_row."id", normalized."name", CURRENT_TIMESTAMP
FROM (
  SELECT DISTINCT COALESCE(NULLIF(BTRIM("state"), ''), 'Unknown') AS "stateName",
         NULLIF(BTRIM("district"), '') AS "name"
  FROM "City"
) normalized
JOIN "GeoState" state_row ON state_row."name" = normalized."stateName"
WHERE normalized."name" IS NOT NULL
ON CONFLICT ("stateId", "name") DO NOTHING;

ALTER TABLE "City" ADD COLUMN "stateId" TEXT;
ALTER TABLE "City" ADD COLUMN "districtId" TEXT;
UPDATE "City" city
SET "stateId" = (
      SELECT state_row."id" FROM "GeoState" state_row
      WHERE state_row."name" = COALESCE(NULLIF(BTRIM(city."state"), ''), 'Unknown')
    ),
    "districtId" = (
      SELECT district_row."id"
      FROM "GeoDistrict" district_row
      JOIN "GeoState" state_row ON state_row."id" = district_row."stateId"
      WHERE state_row."name" = COALESCE(NULLIF(BTRIM(city."state"), ''), 'Unknown')
        AND district_row."name" = NULLIF(BTRIM(city."district"), '')
      LIMIT 1
    );
ALTER TABLE "City" ALTER COLUMN "stateId" SET NOT NULL;
CREATE INDEX "City_stateId_districtId_isActive_idx" ON "City"("stateId", "districtId", "isActive");
ALTER TABLE "City"
  ADD CONSTRAINT "City_stateId_fkey"
  FOREIGN KEY ("stateId") REFERENCES "GeoState"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "City"
  ADD CONSTRAINT "City_districtId_stateId_fkey"
  FOREIGN KEY ("districtId", "stateId") REFERENCES "GeoDistrict"("id", "stateId") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "GeoPincode" (
  "id" TEXT NOT NULL,
  "code" VARCHAR(6) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "GeoPincode_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "GeoPincode_code_key" ON "GeoPincode"("code");
CREATE UNIQUE INDEX "GeoPincode_id_code_key" ON "GeoPincode"("id", "code");
CREATE INDEX "GeoPincode_code_idx" ON "GeoPincode"("code");

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "ServiceAreaPincode"
    WHERE "pincode" !~ '^[1-9][0-9]{5}$'
  ) OR EXISTS (
    SELECT 1 FROM "ServiceArea"
    WHERE "pincode" IS NOT NULL AND "pincode" !~ '^[1-9][0-9]{5}$'
  ) THEN
    RAISE EXCEPTION 'Cannot normalize invalid existing service-area pincodes; correct them before retrying this migration';
  END IF;
END $$;

INSERT INTO "GeoPincode" ("id", "code")
SELECT md5('veedufix:pincode:' || codes."code"), codes."code"
FROM (
  SELECT "pincode" AS "code" FROM "ServiceAreaPincode"
  UNION
  SELECT "pincode" AS "code" FROM "ServiceArea" WHERE "pincode" IS NOT NULL
) codes
ON CONFLICT ("code") DO NOTHING;

ALTER TABLE "ServiceAreaPincode" ADD COLUMN "pincodeId" TEXT;
INSERT INTO "ServiceAreaPincode" ("id", "serviceAreaId", "pincode", "pincodeId")
SELECT md5('veedufix:area-pincode:' || area."id" || ':' || area."pincode"),
       area."id", area."pincode", pincode_row."id"
FROM "ServiceArea" area
JOIN "GeoPincode" pincode_row ON pincode_row."code" = area."pincode"
WHERE area."pincode" IS NOT NULL
ON CONFLICT ("serviceAreaId", "pincode") DO NOTHING;
UPDATE "ServiceAreaPincode" assignment
SET "pincodeId" = pincode_row."id"
FROM "GeoPincode" pincode_row
WHERE pincode_row."code" = assignment."pincode";
ALTER TABLE "ServiceAreaPincode" ALTER COLUMN "pincodeId" SET NOT NULL;
CREATE INDEX "ServiceAreaPincode_pincodeId_idx" ON "ServiceAreaPincode"("pincodeId");
ALTER TABLE "ServiceAreaPincode"
  ADD CONSTRAINT "ServiceAreaPincode_pincodeId_pincode_fkey"
  FOREIGN KEY ("pincodeId", "pincode") REFERENCES "GeoPincode"("id", "code") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ServiceCategory" ADD COLUMN "availabilityMode" TEXT NOT NULL DEFAULT 'INHERITED';
ALTER TABLE "ServiceSubcategory" ADD COLUMN "availabilityMode" TEXT NOT NULL DEFAULT 'INHERITED';
ALTER TABLE "Service" ADD COLUMN "availabilityMode" TEXT NOT NULL DEFAULT 'INHERITED';
ALTER TABLE "ServiceVariant" ADD COLUMN "availabilityMode" TEXT NOT NULL DEFAULT 'INHERITED';
UPDATE "Service" service
SET "availabilityMode" = 'CUSTOM'
WHERE EXISTS (
  SELECT 1 FROM "ServiceAreaService" assignment WHERE assignment."serviceId" = service."id"
);
CREATE INDEX "ServiceCategory_availabilityMode_isActive_idx" ON "ServiceCategory"("availabilityMode", "isActive");
CREATE INDEX "ServiceSubcategory_categoryId_availabilityMode_idx" ON "ServiceSubcategory"("categoryId", "availabilityMode");
CREATE INDEX "Service_availabilityMode_isActive_idx" ON "Service"("availabilityMode", "isActive");
CREATE INDEX "ServiceVariant_serviceId_availabilityMode_idx" ON "ServiceVariant"("serviceId", "availabilityMode");

CREATE TABLE "ServiceAreaCategory" (
  "categoryId" TEXT NOT NULL,
  "serviceAreaId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ServiceAreaCategory_pkey" PRIMARY KEY ("categoryId", "serviceAreaId")
);
CREATE INDEX "ServiceAreaCategory_serviceAreaId_categoryId_idx" ON "ServiceAreaCategory"("serviceAreaId", "categoryId");
ALTER TABLE "ServiceAreaCategory"
  ADD CONSTRAINT "ServiceAreaCategory_categoryId_fkey"
  FOREIGN KEY ("categoryId") REFERENCES "ServiceCategory"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ServiceAreaCategory"
  ADD CONSTRAINT "ServiceAreaCategory_serviceAreaId_fkey"
  FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ServiceAreaSubcategory" (
  "subcategoryId" TEXT NOT NULL,
  "serviceAreaId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ServiceAreaSubcategory_pkey" PRIMARY KEY ("subcategoryId", "serviceAreaId")
);
CREATE INDEX "ServiceAreaSubcategory_serviceAreaId_subcategoryId_idx" ON "ServiceAreaSubcategory"("serviceAreaId", "subcategoryId");
ALTER TABLE "ServiceAreaSubcategory"
  ADD CONSTRAINT "ServiceAreaSubcategory_subcategoryId_fkey"
  FOREIGN KEY ("subcategoryId") REFERENCES "ServiceSubcategory"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ServiceAreaSubcategory"
  ADD CONSTRAINT "ServiceAreaSubcategory_serviceAreaId_fkey"
  FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ServiceAreaVariant" (
  "variantId" TEXT NOT NULL,
  "serviceAreaId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ServiceAreaVariant_pkey" PRIMARY KEY ("variantId", "serviceAreaId")
);
CREATE INDEX "ServiceAreaVariant_serviceAreaId_variantId_idx" ON "ServiceAreaVariant"("serviceAreaId", "variantId");
ALTER TABLE "ServiceAreaVariant"
  ADD CONSTRAINT "ServiceAreaVariant_variantId_fkey"
  FOREIGN KEY ("variantId") REFERENCES "ServiceVariant"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ServiceAreaVariant"
  ADD CONSTRAINT "ServiceAreaVariant_serviceAreaId_fkey"
  FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "WorkerProfileServiceArea" (
  "workerProfileId" TEXT NOT NULL,
  "serviceAreaId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "WorkerProfileServiceArea_pkey" PRIMARY KEY ("workerProfileId", "serviceAreaId")
);
CREATE INDEX "WorkerProfileServiceArea_serviceAreaId_workerProfileId_idx" ON "WorkerProfileServiceArea"("serviceAreaId", "workerProfileId");
ALTER TABLE "WorkerProfileServiceArea"
  ADD CONSTRAINT "WorkerProfileServiceArea_workerProfileId_fkey"
  FOREIGN KEY ("workerProfileId") REFERENCES "WorkerProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "WorkerProfileServiceArea"
  ADD CONSTRAINT "WorkerProfileServiceArea_serviceAreaId_fkey"
  FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- The legacy matcher was city-and-radius based. Mapping each worker to active areas
-- in their assigned city preserves that scope while making assignments explicit.
INSERT INTO "WorkerProfileServiceArea" ("workerProfileId", "serviceAreaId")
SELECT worker."id", area."id"
FROM "WorkerProfile" worker
JOIN "ServiceArea" area ON area."cityId" = worker."cityId" AND area."isActive" = true
WHERE worker."cityId" IS NOT NULL
ON CONFLICT ("workerProfileId", "serviceAreaId") DO NOTHING;
