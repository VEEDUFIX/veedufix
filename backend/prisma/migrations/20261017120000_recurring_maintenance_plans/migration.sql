CREATE TYPE "MaintenancePlanStatus" AS ENUM ('ACTIVE', 'PAUSED', 'CANCELLED');
CREATE TYPE "MaintenanceOccurrenceStatus" AS ENUM ('AWAITING_CONFIRMATION', 'BOOKING_CREATED', 'SKIPPED', 'FAILED', 'CANCELLED');

ALTER TABLE "Service"
  ADD COLUMN "maintenanceEnabled" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "maintenanceIntervalsMonths" INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],
  ADD COLUMN "maintenanceReminderHours" INTEGER NOT NULL DEFAULT 24;

CREATE TABLE "MaintenancePlan" (
  "id" TEXT NOT NULL,
  "customerId" TEXT NOT NULL,
  "serviceId" TEXT NOT NULL,
  "variantId" TEXT,
  "addressId" TEXT NOT NULL,
  "intervalMonths" INTEGER NOT NULL,
  "preferredTime" VARCHAR(5),
  "timezone" TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  "startAt" DATE NOT NULL,
  "endAt" DATE,
  "nextDueAt" DATE NOT NULL,
  "nextSequence" INTEGER NOT NULL DEFAULT 1,
  "status" "MaintenancePlanStatus" NOT NULL DEFAULT 'ACTIVE',
  "confirmationRequired" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "MaintenancePlan_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "MaintenancePlan_intervalMonths_check" CHECK ("intervalMonths" > 0),
  CONSTRAINT "MaintenancePlan_nextSequence_check" CHECK ("nextSequence" > 0),
  CONSTRAINT "MaintenancePlan_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "MaintenancePlan_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "MaintenancePlan_variantId_fkey" FOREIGN KEY ("variantId") REFERENCES "ServiceVariant"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "MaintenancePlan_addressId_fkey" FOREIGN KEY ("addressId") REFERENCES "Address"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE "MaintenanceOccurrence" (
  "id" TEXT NOT NULL,
  "planId" TEXT NOT NULL,
  "sequence" INTEGER NOT NULL,
  "dueAt" DATE NOT NULL,
  "status" "MaintenanceOccurrenceStatus" NOT NULL DEFAULT 'AWAITING_CONFIRMATION',
  "bookingId" TEXT,
  "reminderSentAt" TIMESTAMP(3),
  "attemptCount" INTEGER NOT NULL DEFAULT 0,
  "failureReason" VARCHAR(500),
  "respondedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "MaintenanceOccurrence_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "MaintenanceOccurrence_sequence_check" CHECK ("sequence" > 0),
  CONSTRAINT "MaintenanceOccurrence_planId_fkey" FOREIGN KEY ("planId") REFERENCES "MaintenancePlan"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "MaintenanceOccurrence_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE "MaintenancePlanEvent" (
  "id" TEXT NOT NULL,
  "planId" TEXT NOT NULL,
  "actorId" TEXT,
  "action" VARCHAR(40) NOT NULL,
  "details" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "MaintenancePlanEvent_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "MaintenancePlanEvent_planId_fkey" FOREIGN KEY ("planId") REFERENCES "MaintenancePlan"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "MaintenanceOccurrence_bookingId_key" ON "MaintenanceOccurrence"("bookingId");
CREATE UNIQUE INDEX "MaintenanceOccurrence_planId_sequence_key" ON "MaintenanceOccurrence"("planId", "sequence");
CREATE INDEX "MaintenancePlan_status_nextDueAt_idx" ON "MaintenancePlan"("status", "nextDueAt");
CREATE INDEX "MaintenancePlan_customerId_status_createdAt_idx" ON "MaintenancePlan"("customerId", "status", "createdAt");
CREATE INDEX "MaintenancePlan_serviceId_status_idx" ON "MaintenancePlan"("serviceId", "status");
CREATE INDEX "MaintenancePlan_variantId_idx" ON "MaintenancePlan"("variantId");
CREATE INDEX "MaintenanceOccurrence_status_dueAt_idx" ON "MaintenanceOccurrence"("status", "dueAt");
CREATE INDEX "MaintenanceOccurrence_planId_dueAt_idx" ON "MaintenanceOccurrence"("planId", "dueAt");
CREATE INDEX "MaintenancePlanEvent_planId_createdAt_idx" ON "MaintenancePlanEvent"("planId", "createdAt");
