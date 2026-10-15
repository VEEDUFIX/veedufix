ALTER TABLE "Service"
  ADD COLUMN "guaranteeEnabled" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "guaranteeClaimWindowDays" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "guaranteeIssueCategories" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "guaranteeTerms" TEXT,
  ADD COLUMN "guaranteeExclusions" TEXT,
  ADD COLUMN "guaranteeResolutionTypes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "guaranteeRequiresPartnerReview" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "guaranteeEvidenceRequired" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "BookingService"
  ADD COLUMN "guaranteePolicySnapshot" JSONB;

ALTER TABLE "Dispute"
  ADD COLUMN "issueCategory" VARCHAR(60),
  ADD COLUMN "serviceId" TEXT,
  ADD COLUMN "referenceCode" VARCHAR(32),
  ADD COLUMN "evidencePhotoIds" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "idempotencyKey" VARCHAR(120),
  ADD COLUMN "remedyType" VARCHAR(30),
  ADD COLUMN "remedyStatus" VARCHAR(30),
  ADD COLUMN "reworkProposedAt" TIMESTAMP(3),
  ADD COLUMN "reworkScheduledAt" TIMESTAMP(3),
  ADD COLUMN "reworkCompletedAt" TIMESTAMP(3),
  ADD COLUMN "customerConfirmedAt" TIMESTAMP(3),
  ADD COLUMN "followUpCount" INTEGER NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX "Dispute_referenceCode_key" ON "Dispute"("referenceCode");
CREATE INDEX "Dispute_serviceId_createdAt_idx" ON "Dispute"("serviceId", "createdAt");
ALTER TABLE "Dispute" ADD CONSTRAINT "Dispute_serviceId_fkey"
  FOREIGN KEY ("serviceId") REFERENCES "Service"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE UNIQUE INDEX "Dispute_bookingId_idempotencyKey_key" ON "Dispute"("bookingId", "idempotencyKey");
CREATE INDEX "Dispute_bookingId_createdAt_idx" ON "Dispute"("bookingId", "createdAt");
CREATE INDEX "Dispute_status_createdAt_idx" ON "Dispute"("status", "createdAt");
-- Preflight before deployment: verify no booking has multiple currently-active disputes.
CREATE UNIQUE INDEX "Dispute_one_active_claim_per_booking_key" ON "Dispute"("bookingId")
  WHERE "status" IN ('open', 'under_review', 'action_required', 'approved', 'refund_pending', 'resolved_rework');

CREATE TABLE "DisputeEvent" (
  "id" TEXT NOT NULL,
  "disputeId" TEXT NOT NULL,
  "actorId" TEXT,
  "actorRole" VARCHAR(20) NOT NULL,
  "type" VARCHAR(40) NOT NULL,
  "message" VARCHAR(2000),
  "visibility" VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER',
  "idempotencyKey" VARCHAR(120),
  "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "DisputeEvent_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "DisputeEvent_disputeId_createdAt_idx" ON "DisputeEvent"("disputeId", "createdAt");
CREATE INDEX "DisputeEvent_visibility_createdAt_idx" ON "DisputeEvent"("visibility", "createdAt");
CREATE UNIQUE INDEX "DisputeEvent_disputeId_idempotencyKey_key" ON "DisputeEvent"("disputeId", "idempotencyKey");
ALTER TABLE "DisputeEvent" ADD CONSTRAINT "DisputeEvent_disputeId_fkey"
  FOREIGN KEY ("disputeId") REFERENCES "Dispute"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Notification" ADD COLUMN "dedupeKey" VARCHAR(160);
CREATE UNIQUE INDEX "Notification_userId_dedupeKey_key" ON "Notification"("userId", "dedupeKey");

-- Existing bookings intentionally keep a NULL policy snapshot: current service terms
-- must not be retroactively presented as the terms accepted at the time of booking.
