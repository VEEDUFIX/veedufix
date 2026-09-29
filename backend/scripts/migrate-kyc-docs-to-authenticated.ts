#!/usr/bin/env tsx
/**
 * scripts/migrate-kyc-docs-to-authenticated.ts
 *
 * ONE-TIME MIGRATION SCRIPT — run manually by an operator, never at startup.
 *
 * What it does:
 *   1. Finds worker identity, qualification, and professional documents.
 *   2. Verifies each URL points to this Cloudinary account and the expected
 *      worker-owned folder.
 *   3. Converts public assets to authenticated delivery and stores their IDs.
 *   4. Avoids logging document URLs, which may contain signed access tokens.
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
 * Run after the publicId database migration has been deployed.
 */

import "dotenv/config";
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
  | { status: "skipped"; id: string; reason: string; publicId?: string }
  | { status: "failed"; id: string; error: string };

function safeCloudinaryError(err: unknown): string {
  if (err instanceof Error) return err.message;
  if (!err || typeof err !== "object") return String(err);

  const value = err as {
    http_code?: number;
    error?: { message?: string; http_code?: number };
    message?: string;
  };
  const message = value.error?.message ?? value.message ?? "Cloudinary request failed";
  const code = value.error?.http_code ?? value.http_code;
  return code ? `${message} (HTTP ${code})` : message;
}

// ---------------------------------------------------------------------------
// Core migration helper
// ---------------------------------------------------------------------------

async function migrateAsset(
  recordId: string,
  url: string | null | undefined,
  expectedPrefixes: string[],
  expectedPublicId?: string | null
): Promise<MigrationResult> {
  if (!url?.trim()) {
    return { status: "skipped", id: recordId, reason: "URL is empty or null" };
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(url);
  } catch {
    return { status: "failed", id: recordId, error: "Stored document URL is invalid" };
  }

  const publicId = extractPublicIdFromUrl(url);
  const accountPath = `/${CLOUD_NAME}/image/`;
  if (
    parsedUrl.protocol !== "https:" ||
    parsedUrl.hostname !== "res.cloudinary.com" ||
    parsedUrl.port !== "" ||
    !parsedUrl.pathname.startsWith(accountPath) ||
    !publicId
  ) {
    return { status: "failed", id: recordId, error: "URL is not a valid asset from the configured Cloudinary account" };
  }
  if (!expectedPrefixes.some((prefix) => publicId.startsWith(prefix))) {
    return { status: "failed", id: recordId, error: "Asset is outside the worker-owned document folder" };
  }
  if (expectedPublicId && expectedPublicId !== publicId) {
    return { status: "failed", id: recordId, error: "Stored public ID does not match its document URL" };
  }

  if (parsedUrl.pathname.includes("/image/authenticated/")) {
    return { status: "skipped", id: recordId, reason: "Already authenticated", publicId };
  }
  if (!parsedUrl.pathname.includes("/image/upload/")) {
    return { status: "failed", id: recordId, error: "Asset is not using a supported Cloudinary delivery type" };
  }
  if (isDryRun) {
    return { status: "success", id: recordId, publicId };
  }

  try {
    await cloudinary.uploader.rename(publicId, publicId, {
      type: "upload",
      to_type: "authenticated",
      resource_type: "image",
      invalidate: true
    });
    return { status: "success", id: recordId, publicId };
  } catch (err: unknown) {
    const msg = safeCloudinaryError(err);
    if (msg.toLowerCase().includes("already")) {
      return { status: "skipped", id: recordId, reason: "Already authenticated", publicId };
    }
    try {
      await cloudinary.api.resource(publicId, {
        resource_type: "image",
        type: "authenticated"
      });
      return { status: "skipped", id: recordId, reason: "Already authenticated", publicId };
    } catch {
      // Preserve the original sanitized error when the authenticated lookup fails.
    }
    return { status: "failed", id: recordId, error: msg };
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("=".repeat(64));
  console.log(" Worker Document Migration: public → authenticated delivery");
  console.log("=".repeat(64));
  console.log();

  // --- Aadhaar documents ---
  const profiles = await prisma.workerProfile.findMany({
    select: { id: true, userId: true, aadhaarDocUrl: true, aadhaarDocPublicId: true }
  });

  console.log(`Found ${profiles.length} WorkerProfile rows to check for aadhaarDocUrl.\n`);

  const aadhaarResults: MigrationResult[] = [];
  for (let i = 0; i < profiles.length; i++) {
    const p = profiles[i];
    const prefix = `[${i + 1}/${profiles.length}]`;
    const result = await migrateAsset(
      p.id,
      p.aadhaarDocUrl,
      [
        `veedufix/kyc/${p.userId}/`,
        `veedufix/documents/${p.userId}/`
      ],
      p.aadhaarDocPublicId
    );
    aadhaarResults.push(result);

    const icon = result.status === "success" ? "✅" : result.status === "skipped" ? "⏭️ " : "❌";
    if (result.status === "success" || (result.status === "skipped" && result.publicId)) {
      if (!isDryRun) {
        await prisma.workerProfile.update({
          where: { id: p.id },
          data: { aadhaarDocPublicId: result.publicId }
        });
      }
      console.log(`${prefix} ${icon} Profile ${result.id}: private asset ID recorded`);
    } else if (result.status === "skipped") {
      console.log(`${prefix} ${icon} Profile ${result.id}: skipped — ${result.reason}`);
    } else {
      console.log(`${prefix} ${icon} Profile ${result.id}: FAILED — ${result.error}`);
    }
  }

  // --- Certification documents ---
  const skills = await prisma.workerSkill.findMany({
    select: {
      id: true,
      certificationDocUrl: true,
      certificationDocPublicId: true,
      workerProfile: { select: { userId: true } }
    }
  });

  console.log(`\nFound ${skills.length} WorkerSkill rows to check for certificationDocUrl.\n`);

  const certResults: MigrationResult[] = [];
  for (let i = 0; i < skills.length; i++) {
    const s = skills[i];
    const prefix = `[${i + 1}/${skills.length}]`;
    const result = await migrateAsset(
      s.id,
      s.certificationDocUrl,
      [
        `veedufix/kyc/${s.workerProfile.userId}/`,
        `veedufix/documents/${s.workerProfile.userId}/`
      ],
      s.certificationDocPublicId
    );
    certResults.push(result);

    const icon = result.status === "success" ? "✅" : result.status === "skipped" ? "⏭️ " : "❌";
    if (result.status === "success" || (result.status === "skipped" && result.publicId)) {
      if (!isDryRun) {
        await prisma.workerSkill.update({
          where: { id: s.id },
          data: { certificationDocPublicId: result.publicId }
        });
      }
      console.log(`${prefix} ${icon} Skill ${result.id}: private asset ID recorded`);
    } else if (result.status === "skipped") {
      console.log(`${prefix} ${icon} Skill ${result.id}: skipped — ${result.reason}`);
    } else {
      console.log(`${prefix} ${icon} Skill ${result.id}: FAILED — ${result.error}`);
    }
  }

  const documents = await prisma.workerDocument.findMany({
    select: {
      id: true,
      url: true,
      publicId: true,
      worker: { select: { userId: true } }
    }
  });
  console.log(`\nFound ${documents.length} WorkerDocument rows to check.\n`);

  const documentResults: MigrationResult[] = [];
  for (let i = 0; i < documents.length; i++) {
    const document = documents[i];
    const prefix = `[${i + 1}/${documents.length}]`;
    const result = await migrateAsset(
      document.id,
      document.url,
      [`veedufix/documents/${document.worker.userId}/`],
      document.publicId
    );
    documentResults.push(result);

    const icon = result.status === "success" ? "✅" : result.status === "skipped" ? "⏭️ " : "❌";
    if (result.status === "success" || (result.status === "skipped" && result.publicId)) {
      if (!isDryRun) {
        await prisma.workerDocument.update({
          where: { id: document.id },
          data: { publicId: result.publicId }
        });
      }
      console.log(`${prefix} ${icon} Document ${result.id}: private asset ID recorded`);
    } else if (result.status === "skipped") {
      console.log(`${prefix} ${icon} Document ${result.id}: skipped — ${result.reason}`);
    } else {
      console.log(`${prefix} ${icon} Document ${result.id}: FAILED — ${result.error}`);
    }
  }

  // --- Summary ---
  const allResults = [...aadhaarResults, ...certResults, ...documentResults];
  const successes = allResults.filter(r => r.status === "success").length;
  const skipped = allResults.filter(r => r.status === "skipped").length;
  const failures = allResults.filter(r => r.status === "failed");

  console.log();
  console.log("=".repeat(64));
  console.log(" Summary");
  console.log("=".repeat(64));
  console.log(`  ✅ ${isDryRun ? "Would migrate" : "Migrated"}: ${successes}`);
  console.log(`  ⏭️  Skipped:   ${skipped}`);
  console.log(`  ❌ Failed:    ${failures.length}`);

  if (failures.length > 0) {
    console.log("\nFailed records (require manual inspection):");
    for (const f of failures) {
      if (f.status === "failed") {
        console.log(`  - ID: ${f.id} | Error: ${f.error}`);
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
