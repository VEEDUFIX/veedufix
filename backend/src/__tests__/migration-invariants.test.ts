import { readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const migrationsDirectory = fileURLToPath(
  new URL("../../prisma/migrations/", import.meta.url)
);

describe("SQL-only partial index invariants", () => {
  it("keeps the one-active-claim partial unique index defined", () => {
    const migration = readFileSync(
      new URL(
        "../../prisma/migrations/20261018120000_service_guarantee_claims/migration.sql",
        import.meta.url
      ),
      "utf8"
    );

    expect(migration).toMatch(
      /CREATE\s+UNIQUE\s+INDEX\s+"Dispute_one_active_claim_per_booking_key"[\s\S]*?WHERE\s+"status"\s+IN\s*\(/i
    );
  });

  it("does not allow a later migration to drop the partial unique index", () => {
    const migrationFiles = readdirSync(migrationsDirectory, {
      withFileTypes: true
    })
      .filter((entry) => entry.isDirectory())
      .map((entry) => `${migrationsDirectory}${entry.name}/migration.sql`);

    for (const migrationFile of migrationFiles) {
      const migration = readFileSync(migrationFile, "utf8");
      expect(migration, migrationFile).not.toMatch(
        /DROP\s+INDEX(?:\s+IF\s+EXISTS)?\s+"Dispute_one_active_claim_per_booking_key"/i
      );
    }
  });
});

describe("custom quote migration input safety", () => {
  it("guards legacy itemized quote casts and preserves amount fallback order", () => {
    const migration = readFileSync(
      new URL(
        "../../prisma/migrations/20261015120000_custom_quote_lifecycle/migration.sql",
        import.meta.url
      ),
      "utf8"
    );

    expect(migration).toMatch(
      /'qty',\s*CASE[\s\S]*?::numeric BETWEEN -2147483648 AND 2147483647[\s\S]*?::integer/i
    );
    expect(migration).toMatch(
      /item->>'unitPrice'[\s\S]*?length\(item->>'unitPrice'\) <= 128[\s\S]*?item->>'amount'[\s\S]*?item->>'price'/i
    );
    expect(migration).not.toMatch(/NULLIF\(item->>'qty', ''\)::integer/i);
  });
});

describe("Partner online matching backfill", () => {
  it("synchronizes existing online eligibility with the availability toggle", () => {
    const migration = readFileSync(
      new URL(
        "../../prisma/migrations/20261020120000_sync_partner_online_eligibility/migration.sql",
        import.meta.url
      ),
      "utf8"
    );

    expect(migration).toMatch(
      /UPDATE\s+"WorkerProfile"\s+SET\s+"isOnline"\s*=\s*"isAvailable"\s+WHERE\s+"isOnline"\s+IS\s+DISTINCT\s+FROM\s+"isAvailable"/i
    );
  });
});
