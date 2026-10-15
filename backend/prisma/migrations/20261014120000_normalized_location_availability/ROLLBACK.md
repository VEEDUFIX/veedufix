# Rollback considerations

This migration is additive and leaves the legacy `City.state`, `City.district`, `ServiceArea.pincode`, `ServiceAreaPincode.pincode`, and `WorkerProfile.serviceAreas` fields in place. It does **not** have a safe automatic down migration.

Before rolling back after deployment:

1. Stop writes to catalog availability, Partner area assignments, market geography, and service-area pincode configuration.
2. Take a database backup and export the rows from `ServiceAreaCategory`, `ServiceAreaSubcategory`, `ServiceAreaVariant`, and `WorkerProfileServiceArea`. These relations contain administrator and Partner changes that cannot be reconstructed from the old text columns.
3. Roll the application back to a version that does not read the normalized tables or `availabilityMode` columns. The old version cannot populate the required `City.stateId` or `ServiceAreaPincode.pincodeId` columns, so keep writes to market geography and service-area pincode configuration disabled during this step.
4. Restore old matching behavior from the exported Partner assignments if the legacy city/radius matcher must be reinstated. The migration's initial city-based assignment backfill preserves the previous broad city scope, but later explicit changes are not representable in the old schema.
5. Only after those steps, remove the new constraints, indexes, tables, and columns in a separately reviewed rollback migration. Keep the legacy pincode/text columns until the rollback has been verified. Re-enable writes to the affected tables only after this schema rollback completes.

Do not manually delete rows from the new tables while the new application version is running. Do not run the rollback against production without a tested backup restore and a deployment-specific change window.

The successful `prisma migrate deploy` output shared for the configured Neon database confirms the migration was applied there. This document describes rollback planning; it is not evidence of a production rollback test or backup-restore test.
