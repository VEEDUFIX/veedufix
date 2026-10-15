ALTER TABLE "Booking"
  ADD COLUMN "customQuoteRevision" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "CustomQuoteRevision" (
  "id" TEXT NOT NULL,
  "bookingId" TEXT NOT NULL,
  "version" INTEGER NOT NULL,
  "status" TEXT NOT NULL,
  "requestNotes" TEXT,
  "requestedBy" TEXT NOT NULL,
  "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "submittedBy" TEXT,
  "submittedAt" TIMESTAMP(3),
  "amount" DECIMAL(12,2),
  "taxAmount" DECIMAL(12,2),
  "itemized" JSONB,
  "notes" TEXT,
  "expiresAt" TIMESTAMP(3),
  "respondedBy" TEXT,
  "respondedAt" TIMESTAMP(3),
  "paymentStatus" TEXT NOT NULL DEFAULT 'NOT_REQUIRED',
  "paidAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "CustomQuoteRevision_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "Payment" ADD COLUMN "customQuoteRevisionId" TEXT;
CREATE UNIQUE INDEX "CustomQuoteRevision_bookingId_version_key" ON "CustomQuoteRevision"("bookingId", "version");
CREATE INDEX "CustomQuoteRevision_bookingId_createdAt_idx" ON "CustomQuoteRevision"("bookingId", "createdAt");
CREATE INDEX "CustomQuoteRevision_status_expiresAt_idx" ON "CustomQuoteRevision"("status", "expiresAt");
CREATE INDEX "Payment_customQuoteRevisionId_status_idx" ON "Payment"("customQuoteRevisionId", "status");
ALTER TABLE "CustomQuoteRevision" ADD CONSTRAINT "CustomQuoteRevision_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_customQuoteRevisionId_fkey" FOREIGN KEY ("customQuoteRevisionId") REFERENCES "CustomQuoteRevision"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Preserve existing quote snapshots. An accepted legacy quote has no provable
-- payment record, so it is kept as LEGACY_UNVERIFIED and cannot be charged silently.
INSERT INTO "CustomQuoteRevision" (
  "id", "bookingId", "version", "status", "requestedBy", "requestedAt",
  "submittedAt", "amount", "itemized", "notes", "paymentStatus", "createdAt", "updatedAt"
)
SELECT
  'legacy-' || substr(md5(b."id"), 1, 24), b."id", 1,
  CASE
    WHEN b."customQuoteStatus" IN ('REJECTED', 'DECLINED') THEN 'DECLINED'
    WHEN b."customQuoteStatus" = 'PENDING' AND b."customQuoteAmount" IS NOT NULL THEN 'SUBMITTED'
    WHEN b."customQuoteStatus" = 'PENDING' THEN 'REQUESTED'
    ELSE b."customQuoteStatus"
  END,
  b."customerId", b."createdAt",
  CASE WHEN b."customQuoteStatus" = 'REQUESTED' OR (b."customQuoteStatus" = 'PENDING' AND b."customQuoteAmount" IS NULL) THEN NULL ELSE b."updatedAt" END,
  b."customQuoteAmount",
  CASE
    WHEN jsonb_typeof(b."customQuoteItemized") = 'array' THEN (
      SELECT jsonb_agg(jsonb_build_object(
        'label', COALESCE(item->>'label', 'Item'),
        'qty', CASE
          WHEN COALESCE(item->>'qty', '') ~ '^[+-]?[0-9]{1,11}$' THEN
            CASE
              WHEN (item->>'qty')::numeric BETWEEN -2147483648 AND 2147483647
                THEN (item->>'qty')::integer
              ELSE 1
            END
          ELSE 1
        END,
        'unitPrice', COALESCE(
          CASE WHEN item->>'unitPrice' ~ '^[+-]?([0-9]+(\.[0-9]+)?|\.[0-9]+)$' AND length(item->>'unitPrice') <= 128 THEN (item->>'unitPrice')::numeric END,
          CASE WHEN item->>'amount' ~ '^[+-]?([0-9]+(\.[0-9]+)?|\.[0-9]+)$' AND length(item->>'amount') <= 128 THEN (item->>'amount')::numeric END,
          CASE WHEN item->>'price' ~ '^[+-]?([0-9]+(\.[0-9]+)?|\.[0-9]+)$' AND length(item->>'price') <= 128 THEN (item->>'price')::numeric END,
          0
        )
      ))
      FROM jsonb_array_elements(b."customQuoteItemized") item
    )
    ELSE NULL
  END,
  b."customQuoteNotes",
  CASE WHEN b."customQuoteStatus" = 'ACCEPTED' THEN 'LEGACY_UNVERIFIED' ELSE 'NOT_REQUIRED' END,
  b."createdAt", b."updatedAt"
FROM "Booking" b
WHERE b."customQuoteStatus" IS NOT NULL;

UPDATE "Booking" SET "customQuoteRevision" = 1 WHERE "customQuoteStatus" IS NOT NULL;
UPDATE "Booking" SET "customQuoteStatus" = 'DECLINED' WHERE "customQuoteStatus" = 'REJECTED';
UPDATE "Booking"
SET "customQuoteStatus" = CASE WHEN "customQuoteAmount" IS NOT NULL THEN 'SUBMITTED' ELSE 'REQUESTED' END
WHERE "customQuoteStatus" = 'PENDING';
