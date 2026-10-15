-- The Partner availability toggle historically represented consent to receive
-- instant work. Keep existing opted-in Partners eligible after matching began
-- requiring both availability and online status. Future toggles update both.
UPDATE "WorkerProfile"
SET "isOnline" = "isAvailable"
WHERE "isOnline" IS DISTINCT FROM "isAvailable";
