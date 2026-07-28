import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const email = "4bdulrahmaaaan@gmail.com";
  
  const admin = await prisma.user.upsert({
    where: { email },
    update: {
      role: "ADMIN",
      isActive: true
    },
    create: {
      email,
      name: "Admin User",
      role: "ADMIN",
      isActive: true,
      emailVerifiedAt: new Date()
    }
  });

  console.log(`Successfully made ${admin.email} an ADMIN`);
}

main().finally(() => prisma.$disconnect());
