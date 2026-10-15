import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";

export type ServiceAreaMatch = {
  id: string;
  name: string;
  slug: string;
  cityId: string;
  cityName: string;
  pincodeRangeStart: string | null;
  pincodeRangeEnd: string | null;
  pincode: string | null;
  pincodes: string[];
  serviceAreaIds: string[];
};

const ACTIVE_AREA_MESSAGE = "We don't currently serve this area yet — we're expanding soon!";

function normalizePincode(pincode: string): string {
  return pincode.trim();
}

function asPincodeNumber(value: string | null | undefined): number | null {
  if (!value) return null;
  if (!/^[1-9][0-9]{5}$/.test(value)) return null;
  return Number(value);
}

function matchesArea(
  area: {
    pincode: string | null;
    assignedPincodes?: Array<{ pincode: string }>;
    pincodeRangeStart: string | null;
    pincodeRangeEnd: string | null;
  },
  pincode: string
): boolean {
  if (area.pincode && area.pincode === pincode) {
    return true;
  }
  if (area.assignedPincodes?.some((item) => item.pincode === pincode)) {
    return true;
  }

  const start = asPincodeNumber(area.pincodeRangeStart);
  const end = asPincodeNumber(area.pincodeRangeEnd);
  const target = asPincodeNumber(pincode);
  if (start === null || end === null || target === null) {
    return false;
  }

  return target >= start && target <= end;
}

export async function findServiceableAreas(input: {
  pincode: string;
  cityId?: string;
  city?: string;
}): Promise<ServiceAreaMatch[]> {
  const pincode = normalizePincode(input.pincode);
  if (!/^[1-9][0-9]{5}$/.test(pincode)) {
    return [];
  }

  const normalizedCity = input.city?.trim().toLowerCase();
  const where: Prisma.ServiceAreaWhereInput = {
    isActive: true,
    city: {
      isActive: true,
      ...(normalizedCity
        ? {
            OR: [
              { name: { equals: normalizedCity, mode: "insensitive" } },
              { slug: { equals: normalizedCity, mode: "insensitive" } }
            ]
          }
        : {})
    },
    ...(input.cityId ? { cityId: input.cityId } : {}),
    OR: [
      { pincode },
      { assignedPincodes: { some: { pincode } } },
      { pincodeRangeStart: { lte: pincode }, pincodeRangeEnd: { gte: pincode } }
    ]
  };

  const areas = await prisma.serviceArea.findMany({
    where,
    select: {
      id: true,
      name: true,
      slug: true,
      cityId: true,
      pincode: true,
      assignedPincodes: { select: { pincode: true } },
      pincodeRangeStart: true,
      pincodeRangeEnd: true,
      city: {
        select: {
          id: true,
          name: true,
          slug: true,
          state: true,
          district: true,
          isActive: true
        }
      }
    },
    orderBy: [{ createdAt: "asc" }]
  });

  const matches: ServiceAreaMatch[] = [];
  for (const area of areas) {
    const serviceArea = area as {
      pincode: string | null;
      assignedPincodes: Array<{ pincode: string }>;
      pincodeRangeStart: string | null;
      pincodeRangeEnd: string | null;
    };

    // Prisma applies these filters in the database. Keep the check here too so
    // callers never receive a match from a stale or incomplete query adapter.
    if (input.cityId && area.cityId !== input.cityId) continue;
    if (
      normalizedCity &&
      area.city.name.trim().toLowerCase() !== normalizedCity &&
      area.city.slug.trim().toLowerCase() !== normalizedCity
    ) {
      continue;
    }

    if (matchesArea(serviceArea, pincode)) {
      matches.push({
        id: area.id,
        name: area.name,
        slug: area.slug,
        cityId: area.cityId,
        cityName: area.city.name,
        pincodeRangeStart: serviceArea.pincodeRangeStart,
        pincodeRangeEnd: serviceArea.pincodeRangeEnd,
        pincode: serviceArea.pincode,
        pincodes: (serviceArea.assignedPincodes ?? []).map(
          (item: { pincode: string }) => item.pincode
        ),
        serviceAreaIds: [area.id]
      });
    }
  }

  return matches;
}

export async function findServiceableArea(input: {
  pincode: string;
  cityId?: string;
  city?: string;
}): Promise<ServiceAreaMatch | null> {
  return (await findServiceableAreas(input))[0] ?? null;
}

export async function assertServiceablePincode(input: {
  pincode: string;
  cityId?: string;
  city?: string;
}): Promise<ServiceAreaMatch> {
  const areas = await findServiceableAreas(input);
  if (areas.length === 0) {
    throw AppError.badRequest(ACTIVE_AREA_MESSAGE);
  }
  return {
    ...areas[0],
    serviceAreaIds: areas.map((area) => area.id)
  };
}

export function getServiceAreaUnavailableMessage(): string {
  return ACTIVE_AREA_MESSAGE;
}
