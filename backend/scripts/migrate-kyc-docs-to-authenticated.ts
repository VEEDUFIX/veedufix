#!/usr/bin/env tsx
/**
 * scripts/migrate-kyc-docs-to-authenticated.ts
 *
 * ONE-TIME MIGRATION SCRIPT — run manually by an operator, never at startup.
 *
 * What it does:
 *   1. Reads all WorkerProfile.aadhaarDocUrl values from the DB.
 *   2. Reads all WorkerSkill.certificationDocUrl values from the DB.
 *   3. For each, extracts the Cloudinary public_id from the stored URL using
 *      the extractPublicIdFromUrl helper (URL-parsing fallback).
 *   4. Calls cloudinary.api.update(publicId, { type: "authenticated" }) to
 *      convert the existing public asset to restricted/authenticated delivery.
 *   5. Logs successes and failures clearly; never crashes on a single failure.
 *
 * Run with:
 *   npx tsx scripts/migrate-kyc-docs-to-authenticated.ts [--dry-run]
 *
 * --dry-run   Print what would be migrated without actually calling Cloudinary.
 *
 * Prerequisites:
 *   - Real Cloudinary credentials must be set in the environment (.env or shell).
 *   - The DB must be reachable.
 *
 * NOTE: Assets that are already type:"authenticated" will return an error from
 * Cloudinary's API — this is harmless and is reported as a skip, not a failure.
 */

import { v2 as cloudinary } from "cloudinary";
import { PrismaClient } from "@prisma/client";
import { extractPublicIdFromUrl } from "../src/lib/cloudinary.js";

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

const isDryRun = process.argv.includes("--dry-run");

if (isDryRun) {
  console.log("🔍  DRY RUN — no Cloudinary API calls will be made.\n");
}

const prisma = new PrismaClient();

// Configure Cloudinary from environment variables directly.
const CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME;
const API_KEY = process.env.CLOUDINARY_API_KEY;
const API_SECRET = process.env.CLOUDINARY_API_SECRET;

if (!CLOUD_NAME || !API_KEY || !API_SECRET) {
  console.error("❌  Missing Cloudinary credentials. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET.");
  process.exit(1);
}

cloudinary.config({
  cloud_name: CLOUD_NAME,
  api_key: API_KEY,
  api_secret: API_SECRET,
  secure: true
});

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type MigrationResult =
  | { status: "success"; id: string; publicId: string }
  | { status: "skipped"; id: string; reason: string }
  | { status: "failed"; id: string; url: string; error: string };

// ---------------------------------------------------------------------------
// Core migration helper
// ---------------------------------------------------------------------------

async function migrateAsset(
  recordId: string,
  url: string | null | undefined,
  label: string
): Promise<MigrationResult> {
  if (!url?.trim()) {
    return { status: "skipped", id: recordId, reason: "URL is empty or null" };
  }

  const publicId = extractPublicIdFromUrl(url);
  if (!publicId) {
    return {
      status: "failed",
      id: recordId,
      url,
      error: "Could not parse public_id from URL — manual inspection required"
    };
  }

  if (isDryRun) {
    return { status: "success", id: recordId, publicId };
  }

  try {
    await cloudinary.api.update(publicId, { type: "authenticated", resource_type: "image" });
    return { status: "success", id: recordId, publicId };
  } catch (err: unknown) {
    let msg = "Unknown error";
    if (err instanceof Error) {
      msg = err.message;
    } else if (err && typeof err === "object") {
      msg = (err as any).message || JSON.stringify(err);
    } else {
      msg = String(err);
    }
    // "already authenticated" or similar — treat as harmless skip
    if (msg.toLowerCase().includes("already") || msg.toLowerCase().includes("not found")) {
      return { status: "skipped", id: recordId, reason: `Cloudinary: ${msg}` };
    }
    return { status: "failed", id: recordId, url, error: msg };
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("=".repeat(64));
  console.log(" KYC Document Migration: public → authenticated delivery");
  console.log("=".repeat(64));
  console.log();

  // --- Aadhaar documents ---
  const profiles = await prisma.workerProfile.findMany({
    select: { id: true, aadhaarDocUrl: true }
  });

  console.log(`Found ${profiles.length} WorkerProfile rows to check for aadhaarDocUrl.\n`);

  const aadhaarResults: MigrationResult[] = [];
  for (let i = 0; i < profiles.length; i++) {
    const p = profiles[i];
    const prefix = `[${i + 1}/${profiles.length}]`;
    const result = await migrateAsset(p.id, p.aadhaarDocUrl, "aadhaarDocUrl for profile");
    aadhaarResults.push(result);

    const icon = result.status === "success" ? "✅" : result.status === "skipped" ? "⏭️ " : "❌";
    if (result.status === "success") {
      if (!isDryRun) {
        await prisma.workerProfile.update({
          where: { id: p.id },
          data: { aadhaarDocPublicId: result.publicId }
        });
      }
      console.log(`${prefix} ${icon} Profile ${result.id}: publicId=${result.publicId}`);
    } else if (result.status === "skipped") {
      console.log(`${prefix} ${icon} Profile ${result.id}: skipped — ${result.reason}`);
    } else {
      console.log(`${prefix} ${icon} Profile ${result.id}: FAILED — ${result.error}`);
      console.log(`   URL: ${result.url}`);
    }
  }

  // --- Certification documents ---
  const skills = await prisma.workerSkill.findMany({
    select: { id: true, certificationDocUrl: true }
  });

  console.log(`\nFound ${skills.length} WorkerSkill rows to check for certificationDocUrl.\n`);

  const certResults: MigrationResult[] = [];
  for (let i = 0; i < skills.length; i++) {
    const s = skills[i];
    const prefix = `[${i + 1}/${skills.length}]`;
    const result = await migrateAsset(s.id, s.certificationDocUrl, "certificationDocUrl for skill");
    certResults.push(result);

    const icon = result.status === "success" ? "✅" : result.status === "skipped" ? "⏭️ " : "❌";
    if (result.status === "success") {
      if (!isDryRun) {
        await prisma.workerSkill.update({
          where: { id: s.id },
          data: { certificationDocPublicId: result.publicId }
        });
      }
      console.log(`${prefix} ${icon} Skill ${result.id}: publicId=${result.publicId}`);
    } else if (result.status === "skipped") {
      console.log(`${prefix} ${icon} Skill ${result.id}: skipped — ${result.reason}`);
    } else {
      console.log(`${prefix} ${icon} Skill ${result.id}: FAILED — ${result.error}`);
      console.log(`   URL: ${result.url}`);
    }
  }

  // --- Summary ---
  const allResults = [...aadhaarResults, ...certResults];
  const successes = allResults.filter(r => r.status === "success").length;
  const skipped = allResults.filter(r => r.status === "skipped").length;
  const failures = allResults.filter(r => r.status === "failed");

  console.log();
  console.log("=".repeat(64));
  console.log(" Summary");
  console.log("=".repeat(64));
  console.log(`  ✅ Migrated:  ${successes}`);
  console.log(`  ⏭️  Skipped:   ${skipped}`);
  console.log(`  ❌ Failed:    ${failures.length}`);

  if (failures.length > 0) {
    console.log("\nFailed records (require manual inspection):");
    for (const f of failures) {
      if (f.status === "failed") {
        console.log(`  - ID: ${f.id} | URL: ${f.url} | Error: ${f.error}`);
      }
    }
    console.log();
    console.log("⚠️  Migration completed with errors. Review the failures above before");
    console.log("   considering this migration complete.");
    process.exit(1);
  } else {
    console.log();
    console.log("✅  Migration completed successfully.");
  }
}

main()
  .catch((err) => {
    console.error("❌  Unexpected error during migration:", err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
