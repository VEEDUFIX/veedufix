import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  const adminPasswordHash = await bcrypt.hash("Admin@12345", 10);
  const admin = await prisma.user.upsert({
    where: { email: "admin@veedufix.local" },
    update: {
      name: "VeeduFix Admin",
      role: "ADMIN",
      passwordHash: adminPasswordHash,
      isActive: true
    },
    create: {
      name: "VeeduFix Admin",
      email: "admin@veedufix.local",
      role: "ADMIN",
      passwordHash: adminPasswordHash,
      isActive: true
    }
  });
  console.log("Admin seeded:", admin.email);
}

main().finally(() => prisma.$disconnect());
