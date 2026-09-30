ALTER TABLE "City" ADD COLUMN "district" TEXT;

UPDATE "City"
SET "district" = CASE
  WHEN "slug" = 'chennai' THEN 'Chennai'
  WHEN "slug" = 'bengaluru' THEN 'Bengaluru Urban'
  WHEN "slug" = 'hyderabad' THEN 'Hyderabad'
  ELSE "name"
END
WHERE "district" IS NULL;

UPDATE "City"
SET "isActive" = CASE WHEN "slug" = 'chennai' THEN TRUE ELSE FALSE END
WHERE "slug" IN ('chennai', 'bengaluru', 'hyderabad');
