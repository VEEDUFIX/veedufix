# Rollback considerations

This data-only migration synchronizes `WorkerProfile.isOnline` with the
historical availability toggle (`isAvailable`). The previous values cannot be
reconstructed from the migrated rows, so this migration has no lossless SQL
rollback. Restore the affected values from a pre-deploy database snapshot if a
rollback is required. Do not roll back the application to code that expects
the pre-sync online-state behavior without reviewing matching eligibility.
