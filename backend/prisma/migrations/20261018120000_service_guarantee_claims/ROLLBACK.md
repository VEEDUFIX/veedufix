# Rollback notes

This migration is additive. To roll back before enabling claims, deploy an application version that no longer reads or writes these fields, then apply a reviewed rollback during a maintenance window:

```sql
DROP TABLE IF EXISTS "DisputeEvent";
DROP INDEX IF EXISTS "Notification_userId_dedupeKey_key";
ALTER TABLE "Notification" DROP COLUMN IF EXISTS "dedupeKey";
DROP INDEX IF EXISTS "DisputeEvent_disputeId_idempotencyKey_key";
DROP INDEX IF EXISTS "Dispute_one_active_claim_per_booking_key";
DROP INDEX IF EXISTS "Dispute_serviceId_createdAt_idx";
DROP INDEX IF EXISTS "Dispute_status_createdAt_idx";
DROP INDEX IF EXISTS "Dispute_bookingId_createdAt_idx";
DROP INDEX IF EXISTS "Dispute_bookingId_idempotencyKey_key";
DROP INDEX IF EXISTS "Dispute_referenceCode_key";
ALTER TABLE "Dispute"
  DROP COLUMN IF EXISTS "issueCategory",
  DROP COLUMN IF EXISTS "serviceId",
  DROP COLUMN IF EXISTS "referenceCode",
  DROP COLUMN IF EXISTS "evidencePhotoIds",
  DROP COLUMN IF EXISTS "idempotencyKey",
  DROP COLUMN IF EXISTS "remedyType",
  DROP COLUMN IF EXISTS "remedyStatus",
  DROP COLUMN IF EXISTS "reworkProposedAt",
  DROP COLUMN IF EXISTS "reworkScheduledAt",
  DROP COLUMN IF EXISTS "reworkCompletedAt",
  DROP COLUMN IF EXISTS "customerConfirmedAt",
  DROP COLUMN IF EXISTS "followUpCount";
ALTER TABLE "BookingService" DROP COLUMN IF EXISTS "guaranteePolicySnapshot";
ALTER TABLE "Service"
  DROP COLUMN IF EXISTS "guaranteeEnabled",
  DROP COLUMN IF EXISTS "guaranteeClaimWindowDays",
  DROP COLUMN IF EXISTS "guaranteeIssueCategories",
  DROP COLUMN IF EXISTS "guaranteeTerms",
  DROP COLUMN IF EXISTS "guaranteeExclusions",
  DROP COLUMN IF EXISTS "guaranteeResolutionTypes",
  DROP COLUMN IF EXISTS "guaranteeRequiresPartnerReview",
  DROP COLUMN IF EXISTS "guaranteeEvidenceRequired";
```

Rolling back drops claim history, evidence references, and configured policy values. Export those records first if any claims or policies have been created. Never use this rollback against production without an approved recovery plan.
