-- This migration is intentionally forward-only in normal releases.
-- Rollback deletes quote revisions and can discard customer decisions and quote-payment links.
-- Before rollback, export CustomQuoteRevision and Payment.customQuoteRevisionId values.
```sql
BEGIN;
ALTER TABLE "Payment" DROP CONSTRAINT IF EXISTS "Payment_customQuoteRevisionId_fkey";
DROP INDEX IF EXISTS "Payment_customQuoteRevisionId_status_idx";
ALTER TABLE "Payment" DROP COLUMN IF EXISTS "customQuoteRevisionId";
DROP TABLE IF EXISTS "CustomQuoteRevision";
ALTER TABLE "Booking" DROP COLUMN IF EXISTS "customQuoteRevision";
UPDATE "Booking" SET "customQuoteStatus" = 'REJECTED' WHERE "customQuoteStatus" IN ('DECLINED', 'EXPIRED');
UPDATE "Booking" SET "customQuoteStatus" = 'PENDING' WHERE "customQuoteStatus" IN ('REQUESTED', 'SUBMITTED');
-- Legacy Booking customQuote* projection fields are retained.
COMMIT;
```
