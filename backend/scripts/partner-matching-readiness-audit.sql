-- Read-only pre-deploy audit for the stricter Partner matcher.
-- Run against the intended deployment branch only after confirming the target.
-- This script does not change data. It counts approved, verified Partners who
-- are missing each data prerequisite used by candidate matching.

WITH eligible_partners AS (
  SELECT
    worker."id",
    worker."latitude",
    worker."longitude",
    worker."isOnline",
    worker."isAvailable"
  FROM "WorkerProfile" AS worker
  WHERE worker."onboardingStatus" = 'approved'
    AND worker."verificationStatus" = 'VERIFIED'
)
SELECT
  count(*) AS "approvedVerifiedPartners",
  count(*) FILTER (WHERE partner."isOnline" = true) AS "currentlyOnlinePartners",
  count(*) FILTER (
    WHERE partner."isAvailable" = true AND partner."isOnline" = false
  ) AS "availableButOfflinePartners",
  count(*) FILTER (
    WHERE NOT EXISTS (
      SELECT 1
      FROM "WorkerProfileServiceArea" AS assignment
      JOIN "ServiceArea" AS area ON area."id" = assignment."serviceAreaId"
      WHERE assignment."workerProfileId" = partner."id"
        AND area."isActive" = true
    )
  ) AS "missingActiveServiceAreaAssignment",
  count(*) FILTER (
    WHERE NOT EXISTS (
      SELECT 1
      FROM "WorkerAvailability" AS slot
      WHERE slot."workerId" = partner."id"
    )
  ) AS "missingWeeklyAvailability",
  count(*) FILTER (
    WHERE NOT EXISTS (
      SELECT 1
      FROM "WorkerProfileServiceArea" AS assignment
      JOIN "ServiceArea" AS area ON area."id" = assignment."serviceAreaId"
      JOIN "City" AS city ON city."id" = area."cityId"
      WHERE assignment."workerProfileId" = partner."id"
        AND area."isActive" = true
        AND city."isActive" = true
    )
  ) AS "missingActiveCityServiceAreaAssignment",
  count(*) FILTER (
    WHERE NOT EXISTS (
      SELECT 1
      FROM "WorkerSkill" AS skill
      WHERE skill."workerProfileId" = partner."id"
        AND skill."verifiedByAdmin" = true
    )
  ) AS "missingAnyVerifiedSkill",
  count(*) FILTER (
    WHERE NOT EXISTS (
      SELECT 1
      FROM "WorkerService" AS service
      WHERE service."workerId" = partner."id"
        AND service."isAvailable" = true
    )
  ) AS "missingAnyAvailableService",
  count(*) FILTER (
    WHERE partner."latitude" IS NULL OR partner."longitude" IS NULL
  ) AS "missingCoordinates"
FROM eligible_partners AS partner;
