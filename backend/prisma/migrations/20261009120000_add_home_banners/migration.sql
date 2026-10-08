CREATE TABLE "HomeBanner" (
    "id" TEXT NOT NULL,
    "imageUrl" VARCHAR(2048) NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "destinationType" VARCHAR(32) NOT NULL,
    "destinationValue" VARCHAR(512) NOT NULL,
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "HomeBanner_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "HomeBanner_isActive_sortOrder_startsAt_endsAt_idx"
ON "HomeBanner"("isActive", "sortOrder", "startsAt", "endsAt");
