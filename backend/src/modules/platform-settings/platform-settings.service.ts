import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";

type CommissionRecord = {
  id: string;
  cityId: string | null;
  cityName: string | null;
  citySlug: string | null;
  rate: number;
  fixedFee: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

function toNumber(value: Prisma.Decimal | number | string | null | undefined): number {
  if (value === null || value === undefined) {
    return 0;
  }
  return typeof value === "number" ? value : Number(value);
}

function serializeCommission(record: {
  id: string;
  cityId: string | null;
  rate: Prisma.Decimal;
  fixedFee: Prisma.Decimal;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
  city?: { name: string; slug: string } | null;
}): CommissionRecord {
  return {
    id: record.id,
    cityId: record.cityId,
    cityName: record.city?.name ?? null,
    citySlug: record.city?.slug ?? null,
    rate: toNumber(record.rate),
    fixedFee: toNumber(record.fixedFee),
    isActive: record.isActive,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString()
  };
}

export async function getPlatformSettings() {
  const [platformConfig, invoiceSequence, commissions, cities] = await Promise.all([
    prisma.platformConfig.upsert({
      where: { key: "primary" },
      create: {
        key: "primary",
        gstin: null,
        legalBusinessName: null,
        registeredAddress: null
      },
      update: {}
    }),
    prisma.invoiceSequence.upsert({
      where: { key: "invoice" },
      create: {
        key: "invoice",
        currentValue: 0
      },
      update: {}
    }),
    prisma.commissions.findMany({
      include: {
        city: {
          select: {
            name: true,
            slug: true
          }
        }
      },
      orderBy: [
        { cityId: "asc" },
        { createdAt: "desc" }
      ]
    }),
    prisma.city.findMany({
      select: {
        id: true,
        name: true,
        slug: true,
        state: true,
        isActive: true
      },
      orderBy: { name: "asc" }
    })
  ]);

  return {
    platformConfig: {
      key: platformConfig.key,
      gstin: platformConfig.gstin,
      legalBusinessName: platformConfig.legalBusinessName,
      registeredAddress: platformConfig.registeredAddress,
      createdAt: platformConfig.createdAt.toISOString(),
      updatedAt: platformConfig.updatedAt.toISOString()
    },
    invoiceSequence: {
      key: invoiceSequence.key,
      currentValue: invoiceSequence.currentValue,
      createdAt: invoiceSequence.createdAt.toISOString(),
      updatedAt: invoiceSequence.updatedAt.toISOString()
    },
    commissions: commissions.map((commission) =>
      serializeCommission(commission as Parameters<typeof serializeCommission>[0])
    ),
    cities: cities.map((city) => ({
      id: city.id,
      name: city.name,
      slug: city.slug,
      state: city.state,
      isActive: city.isActive
    }))
  };
}

export async function savePlatformSettings(payload: Record<string, unknown>) {
  const gstin = typeof payload.gstin === "string" ? payload.gstin.trim() : null;
  const legalBusinessName = typeof payload.legalBusinessName === "string" ? payload.legalBusinessName.trim() : null;
  const registeredAddress = typeof payload.registeredAddress === "string" ? payload.registeredAddress.trim() : null;
  const invoiceSequenceCurrentValue = typeof payload.invoiceSequenceCurrentValue === "number"
    ? payload.invoiceSequenceCurrentValue
    : typeof payload.invoiceSequenceCurrentValue === "string"
      ? Number(payload.invoiceSequenceCurrentValue)
      : undefined;

  await prisma.$transaction([
    prisma.platformConfig.upsert({
      where: { key: "primary" },
      create: {
        key: "primary",
        gstin: gstin || null,
        legalBusinessName: legalBusinessName || null,
        registeredAddress: registeredAddress || null
      },
      update: {
        gstin: gstin || null,
        legalBusinessName: legalBusinessName || null,
        registeredAddress: registeredAddress || null
      }
    }),
    invoiceSequenceCurrentValue === undefined || Number.isNaN(invoiceSequenceCurrentValue)
      ? prisma.invoiceSequence.upsert({
          where: { key: "invoice" },
          create: { key: "invoice", currentValue: 0 },
          update: {}
        })
      : prisma.invoiceSequence.upsert({
          where: { key: "invoice" },
          create: {
            key: "invoice",
            currentValue: Math.max(0, Math.floor(invoiceSequenceCurrentValue))
          },
          update: {
            currentValue: Math.max(0, Math.floor(invoiceSequenceCurrentValue))
          }
        })
  ]);

  return getPlatformSettings();
}

export async function listCommissions() {
  const settings = await getPlatformSettings();
  return {
    commissions: settings.commissions,
    cities: settings.cities
  };
}

export async function saveCommission(commissionId: string | null, payload: Record<string, unknown>) {
  const cityId = typeof payload.cityId === "string" ? payload.cityId.trim() : null;
  const rate = typeof payload.rate === "number" ? payload.rate : Number(payload.rate);
  const fixedFee = typeof payload.fixedFee === "number" ? payload.fixedFee : Number(payload.fixedFee);
  const isActive = typeof payload.isActive === "boolean" ? payload.isActive : true;

  if (Number.isNaN(rate) || Number.isNaN(fixedFee)) {
    throw new Error("rate and fixedFee are required");
  }

  const existing = commissionId
    ? await prisma.commissions.findUnique({ where: { id: commissionId } })
    : await prisma.commissions.findFirst({
        where: {
          cityId
        }
      });

  const saved = existing
    ? await prisma.commissions.update({
        where: { id: existing.id },
        data: {
          cityId,
          rate,
          fixedFee,
          isActive
        }
      })
    : await prisma.commissions.create({
        data: {
          cityId,
          rate,
          fixedFee,
          isActive
        }
      });

  const city = cityId
    ? await prisma.city.findUnique({
        where: { id: cityId },
        select: { name: true, slug: true }
      })
    : null;

  return {
    commission: serializeCommission({
      ...saved,
      city
    })
  };
}

export async function deleteCommission(commissionId: string) {
  await prisma.commissions.delete({
    where: { id: commissionId }
  });
}
