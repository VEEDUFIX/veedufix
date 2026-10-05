ALTER TABLE "Refund"
ADD COLUMN "gatewayAmount" DOUBLE PRECISION,
ADD COLUMN "walletAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN "walletCreditedAt" TIMESTAMP(3);

-- Existing refunds were recorded as Razorpay refunds, so preserve that allocation.
UPDATE "Refund"
SET "gatewayAmount" = "amount"
WHERE "gatewayAmount" IS NULL;
