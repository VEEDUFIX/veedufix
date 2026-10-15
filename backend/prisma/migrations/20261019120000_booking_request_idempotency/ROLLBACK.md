# Rollback

This additive migration stores checkout request keys and their canonical
payload hashes on bookings. Before rollback, confirm no deployment still relies
on these columns for retry safety. Then drop the unique index and both columns:

```sql
DROP INDEX IF EXISTS "Booking_customerId_clientRequestKey_key";
ALTER TABLE "Booking"
  DROP COLUMN IF EXISTS "clientRequestHash",
  DROP COLUMN IF EXISTS "clientRequestKey";
```
