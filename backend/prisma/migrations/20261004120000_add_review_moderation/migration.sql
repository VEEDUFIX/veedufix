ALTER TABLE "Review"
ADD COLUMN "moderationStatus" TEXT NOT NULL DEFAULT 'published';

CREATE INDEX "Review_moderationStatus_createdAt_idx"
ON "Review"("moderationStatus", "createdAt");

CREATE TABLE "ReviewReport" (
  "id" TEXT NOT NULL,
  "reviewId" TEXT NOT NULL,
  "reporterId" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'open',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ReviewReport_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ReviewReport_reviewId_reporterId_key"
ON "ReviewReport"("reviewId", "reporterId");
CREATE INDEX "ReviewReport_status_createdAt_idx"
ON "ReviewReport"("status", "createdAt");

ALTER TABLE "ReviewReport"
ADD CONSTRAINT "ReviewReport_reviewId_fkey"
FOREIGN KEY ("reviewId") REFERENCES "Review"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ReviewReport"
ADD CONSTRAINT "ReviewReport_reporterId_fkey"
FOREIGN KEY ("reporterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
