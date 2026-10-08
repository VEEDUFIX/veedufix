CREATE TABLE "HomeServiceSection" (
    "id" TEXT NOT NULL,
    "title" VARCHAR(120) NOT NULL,
    "subtitle" VARCHAR(240),
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "seeAllDestination" VARCHAR(512) NOT NULL DEFAULT '/search',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "HomeServiceSection_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "HomeServiceSectionItem" (
    "sectionId" TEXT NOT NULL,
    "serviceId" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "HomeServiceSectionItem_pkey" PRIMARY KEY ("sectionId", "serviceId")
);

CREATE INDEX "HomeServiceSection_isActive_sortOrder_idx"
ON "HomeServiceSection"("isActive", "sortOrder");

CREATE INDEX "HomeServiceSectionItem_serviceId_idx"
ON "HomeServiceSectionItem"("serviceId");

CREATE INDEX "HomeServiceSectionItem_sectionId_sortOrder_idx"
ON "HomeServiceSectionItem"("sectionId", "sortOrder");

ALTER TABLE "HomeServiceSectionItem"
ADD CONSTRAINT "HomeServiceSectionItem_sectionId_fkey"
FOREIGN KEY ("sectionId") REFERENCES "HomeServiceSection"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "HomeServiceSectionItem"
ADD CONSTRAINT "HomeServiceSectionItem_serviceId_fkey"
FOREIGN KEY ("serviceId") REFERENCES "Service"("id")
ON DELETE CASCADE ON UPDATE CASCADE;