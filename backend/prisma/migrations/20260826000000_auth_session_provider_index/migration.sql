-- Allow multiple auth sessions per provider identity and keep session IDs aligned with JWT payloads.
DROP INDEX IF EXISTS "AuthSession_providerId_key";

CREATE INDEX IF NOT EXISTS "AuthSession_providerId_idx" ON "AuthSession"("providerId");
