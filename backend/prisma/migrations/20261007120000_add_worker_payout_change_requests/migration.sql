CREATE TABLE "WorkerPayoutChangeRequest" (
    "id" TEXT NOT NULL,
    "workerProfileId" TEXT NOT NULL,
    "pendingKey" TEXT,
    "bankAccountNumber" TEXT,
    "bankIfsc" TEXT,
    "upiId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "rejectionReason" TEXT,
    "reviewedBy" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WorkerPayoutChangeRequest_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "WorkerPayoutChangeRequest_pendingKey_key" ON "WorkerPayoutChangeRequest"("pendingKey");
CREATE INDEX "WorkerPayoutChangeRequest_status_createdAt_idx" ON "WorkerPayoutChangeRequest"("status", "createdAt");
CREATE INDEX "WorkerPayoutChangeRequest_workerProfileId_createdAt_idx" ON "WorkerPayoutChangeRequest"("workerProfileId", "createdAt");

ALTER TABLE "WorkerPayoutChangeRequest"
ADD CONSTRAINT "WorkerPayoutChangeRequest_workerProfileId_fkey"
FOREIGN KEY ("workerProfileId") REFERENCES "WorkerProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
