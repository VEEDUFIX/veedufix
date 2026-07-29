#!/usr/bin/env tsx
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const testUsers = await prisma.user.findMany({
    where: {
      OR: [
        { email: { contains: "@test.com" } },
        { name: { in: ["Test Worker 1", "Test Worker 2", "Test Admin", "Test Legacy"] } }
      ]
    },
    include: {
      workerProfile: {
        select: {
          id: true,
          onboardingStatus: true,
          aadhaarDocUrl: true,
          aadhaarDocPublicId: true,
          createdAt: true,
          skills: { select: { id: true, certificationDocUrl: true, certificationDocPublicId: true } }
        }
      }
    },
    orderBy: { createdAt: "desc" }
  });

  if (testUsers.length === 0) {
    console.log("No test records found.");
    return;
  }

  console.log(`Found ${testUsers.length} test User record(s):\n`);
  for (const u of testUsers) {
    console.log(`  User: id=${u.id}  name="${u.name}"  email=${u.email}  role=${u.role}  createdAt=${u.createdAt.toISOString()}`);
    if (u.workerProfile) {
      const p = u.workerProfile;
      console.log(`    WorkerProfile: id=${p.id}  status=${p.onboardingStatus}  aadhaarDocPublicId=${p.aadhaarDocPublicId ?? "null"}  createdAt=${p.createdAt.toISOString()}`);
      if (p.aadhaarDocUrl) console.log(`    aadhaarDocUrl=${p.aadhaarDocUrl}`);
      for (const s of p.skills) {
        console.log(`    WorkerSkill: id=${s.id}  certPublicId=${s.certificationDocPublicId ?? "null"}  certUrl=${s.certificationDocUrl ?? "null"}`);
      }
    }
    console.log();
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
