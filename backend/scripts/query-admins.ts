import { PrismaClient } from "@prisma/client";
const p = new PrismaClient();
p.user.findMany({
  where: { role: "ADMIN" },
  select: { id: true, email: true, phone: true, createdAt: true, updatedAt: true }
}).then(r => {
  console.log(JSON.stringify(r, null, 2));
}).finally(() => p.$disconnect());
