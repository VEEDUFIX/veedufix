ALTER TABLE "PlatformConfig"
ADD COLUMN "referralsEnabled" BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN "referralMaxSuccessfulPerReferrer" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "payoutsPaused" BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN "payoutPauseReason" TEXT;

ALTER TABLE "User"
ADD COLUMN "referralRewardsIssued" INTEGER NOT NULL DEFAULT 0;

UPDATE "User" AS u
SET "referralRewardsIssued" = referrals.reward_count
FROM (
  SELECT "referrerId", COUNT(*)::INTEGER AS reward_count
  FROM "Referral"
  WHERE status = 'completed'
  GROUP BY "referrerId"
) AS referrals
WHERE u.id = referrals."referrerId";
