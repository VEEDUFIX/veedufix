#!/usr/bin/env tsx
/**
 * scripts/cleanup-test-records.ts
 *
 * ONE-TIME cleanup script — deletes the 13 test User/WorkerProfile records
 * created during the 2026-07-28 KYC E2E verification session.
 *
 * Run with --dry-run to preview; run without to actually delete.
 *
 * NOTE: The Cloudinary asset attached to WorkerProfile cms4sxavl0001trrga4eu4ktr
 * is NOT deleted by this script. That must be a separate, deliberate action.
 */

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const isDryRun = process.argv.includes("--dry-run");

// ---------------------------------------------------------------------------
// Exact IDs — hardcoded, no pattern matching
// ---------------------------------------------------------------------------

const TARGET_USER_IDS = [
  "cms4sxjen0007trrg6akq0exc", // Test Legacy   (run 4)
  "cms4sxbju0004trrgj87n4eyw", // Test Admin    (run 4)
  "cms4sxbag0002trrga7wvi0p3", // Test Worker 2 (run 4)
  "cms4sxavl0000trrg7od9zrlp", // Test Worker 1 (run 4) — has Cloudinary asset
  "cms4ssztw0004trwc2iicskkq", // Test Admin    (run 3)
  "cms4sszml0002trwch1qv72xf", // Test Worker 2 (run 3)
  "cms4ssz8q0000trwc9uoud2vs", // Test Worker 1 (run 3)
  "cms4skmv30004tresd6vhx4ay", // Test Admin    (run 2)
  "cms4skmfu0002trestprva9wl", // Test Worker 2 (run 2)
  "cms4skl7l0000tresmc0noewd", // Test Worker 1 (run 2)
  "cms4siu5n0004trps0zivoy98", // Test Admin    (run 1)
  "cms4sityh0002trpszp5dqymu", // Test Worker 2 (run 1)
  "cms4sit9e0000trpshqtuvt1i", // Test Worker 1 (run 1)
];

async function main() {
  console.log("=".repeat(64));
  console.log(isDryRun ? " DRY-RUN: Test Record Cleanup Preview" : " Test Record Cleanup — LIVE DELETE");
  console.log("=".repeat(64));
  console.log();

  // -------------------------------------------------------------------------
  // 1. Fetch all Users and their linked WorkerProfiles / skills
  // -------------------------------------------------------------------------
  const users = await prisma.user.findMany({
    where: { id: { in: TARGET_USER_IDS } },
    include: {
      workerProfile: {
        include: {
          skills: { select: { id: true, certificationDocUrl: true, certificationDocPublicId: true } }
        }
      }
    },
    orderBy: { createdAt: "asc" }
  });

  // -------------------------------------------------------------------------
  // 2. Cross-check: warn if any target ID was not found
  // -------------------------------------------------------------------------
  const foundIds = new Set(users.map(u => u.id));
  const missingIds = TARGET_USER_IDS.filter(id => !foundIds.has(id));
  if (missingIds.length > 0) {
    console.log("⚠️  The following target IDs were NOT found in the DB (already deleted?):");
    for (const id of missingIds) console.log(`   - ${id}`);
    console.log();
  }

  // -------------------------------------------------------------------------
  // 3. Print full preview of what will be deleted
  // -------------------------------------------------------------------------
  console.log(`Found ${users.length} User record(s) to delete:\n`);

  const cloudinaryWarnings: string[] = [];

  for (const u of users) {
    console.log(`  User: ${u.id}  "${u.name}"  <${u.email}>  role=${u.role}  createdAt=${u.createdAt.toISOString()}`);
    if (u.workerProfile) {
      const p = u.workerProfile;
      console.log(`    └─ WorkerProfile: ${p.id}  status=${p.onboardingStatus}`);
      if ((p as any).aadhaarDocPublicId || (p as any).aadhaarDocUrl) {
        const publicId = (p as any).aadhaarDocPublicId;
        const url = (p as any).aadhaarDocUrl;
        console.log(`       ⚠️  HAS CLOUDINARY ASSET: publicId=${publicId ?? "(parsed from URL)"}  url=${url}`);
        cloudinaryWarnings.push(`WorkerProfile ${p.id} (User ${u.id} "${u.name}"): publicId=${publicId ?? "null"}, url=${url}`);
      }
      for (const s of p.skills) {
        console.log(`       └─ WorkerSkill: ${s.id}  certPublicId=${s.certificationDocPublicId ?? "null"}`);
        if (s.certificationDocPublicId || s.certificationDocUrl) {
          cloudinaryWarnings.push(`WorkerSkill ${s.id}: certPublicId=${s.certificationDocPublicId ?? "null"}`);
        }
      }
    }
    console.log();
  }

  // -------------------------------------------------------------------------
  // 4. Cloudinary asset warning
  // -------------------------------------------------------------------------
  if (cloudinaryWarnings.length > 0) {
    console.log("=".repeat(64));
    console.log(" ⚠️  CLOUDINARY ASSETS — NOT DELETED BY THIS SCRIPT");
    console.log("=".repeat(64));
    console.log(" The following Cloudinary assets will become orphaned (unused");
    console.log(" storage) after the DB rows are deleted. They are NOT deleted");
    console.log(" here. Delete them manually from Cloudinary dashboard or via");
    console.log(" cloudinary.api.delete_resources([publicId]) if desired.");
    console.log();
    for (const w of cloudinaryWarnings) console.log(`  - ${w}`);
    console.log();
  }

  // -------------------------------------------------------------------------
  // 5. Summary counts
  // -------------------------------------------------------------------------
  const profileCount = users.filter(u => u.workerProfile).length;
  const skillCount = users.reduce((n, u) => n + (u.workerProfile?.skills.length ?? 0), 0);

  console.log("=".repeat(64));
  console.log(" Deletion plan summary");
  console.log("=".repeat(64));
  console.log(`  Users to delete:          ${users.length}`);
  console.log(`  WorkerProfiles to delete: ${profileCount}  (cascade via User)`);
  console.log(`  WorkerSkills to delete:   ${skillCount}    (cascade via WorkerProfile)`);
  console.log(`  Cloudinary assets:        ${cloudinaryWarnings.length}  (NOT deleted — see warning above)`);
  console.log();

  if (isDryRun) {
    console.log("🔍  DRY-RUN complete. No records were deleted.");
    console.log("    Re-run without --dry-run to perform the actual deletion.");
    return;
  }

  // -------------------------------------------------------------------------
  // 6. Delete — WorkerProfiles/Skills first (FK safety), then Users
  //    Prisma cascades WorkerSkills via WorkerProfile, so deleting
  //    WorkerProfile is sufficient; Users are deleted last.
  // -------------------------------------------------------------------------
  const profileIds = users.flatMap(u => u.workerProfile ? [u.workerProfile.id] : []);

  if (profileIds.length > 0) {
    const deletedSkills = await prisma.workerSkill.deleteMany({
      where: { workerProfileId: { in: profileIds } }
    });
    console.log(`  Deleted ${deletedSkills.count} WorkerSkill row(s).`);

    const deletedProfiles = await prisma.workerProfile.deleteMany({
      where: { id: { in: profileIds } }
    });
    console.log(`  Deleted ${deletedProfiles.count} WorkerProfile row(s).`);
  }

  const deletedUsers = await prisma.user.deleteMany({
    where: { id: { in: TARGET_USER_IDS } }
  });
  console.log(`  Deleted ${deletedUsers.count} User row(s).`);

  console.log();
  console.log("✅  Cleanup complete.");
}

main()
  .catch((err) => {
    console.error("❌  Unexpected error:", err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
