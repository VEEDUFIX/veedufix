/**
 * Quick script to mark services as requiresSiteVisit = true by name or slug.
 * Usage: npx tsx scripts/mark-site-visit-services.ts
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// ─── Configure: add the slugs or names of services that need a site visit ────
const SITE_VISIT_SLUGS: string[] = [
  // Add your service slugs here, e.g.:
  // 'full-home-painting',
  // 'bathroom-renovation',
  // 'kitchen-remodeling',
];

async function main() {
  if (SITE_VISIT_SLUGS.length === 0) {
    console.log('No slugs configured. Edit SITE_VISIT_SLUGS in this script and re-run.');
    // List all services so user can pick slugs
    const all = await prisma.service.findMany({
      select: { slug: true, name: true, requiresSiteVisit: true },
      orderBy: { name: 'asc' },
    });
    console.table(all);
    return;
  }

  const result = await prisma.service.updateMany({
    where: { slug: { in: SITE_VISIT_SLUGS } },
    data: { requiresSiteVisit: true },
  });

  console.log(`✅ Marked ${result.count} service(s) as requiresSiteVisit = true`);

  // Confirm
  const updated = await prisma.service.findMany({
    where: { slug: { in: SITE_VISIT_SLUGS } },
    select: { slug: true, name: true, requiresSiteVisit: true },
  });
  console.table(updated);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
