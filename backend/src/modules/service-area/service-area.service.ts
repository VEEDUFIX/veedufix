import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";

export type ServiceAreaMatch = {
  id: string;
  name: string;
  slug: string;
  cityId: string;
  cityName: string;
  pincodeRangeStart: string | null;
  pincodeRangeEnd: string | null;
  pincode: string | null;
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
    pincodeRangeStart: string | null;
    pincodeRangeEnd: string | null;
  },
  pincode: string
): boolean {
  if (area.pincode && area.pincode === pincode) {
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

export async function findServiceableArea(input: {
  pincode: string;
  cityId?: string;
  city?: string;
}): Promise<ServiceAreaMatch | null> {
  const pincode = normalizePincode(input.pincode);
  if (!/^[1-9][0-9]{5}$/.test(pincode)) {
    return null;
  }

  const where: Prisma.ServiceAreaWhereInput = {
    isActive: true,
    ...(input.cityId ? { cityId: input.cityId } : {})
  };

  const areas = await prisma.serviceArea.findMany({
    where,
    select: {
      id: true,
      name: true,
      slug: true,
      cityId: true,
      pincode: true,
      pincodeRangeStart: true,
      pincodeRangeEnd: true,
      city: {
        select: { id: true, name: true, slug: true }
      }
    },
    orderBy: [{ createdAt: "asc" }]
  });

  const normalizedCity = input.city?.trim().toLowerCase();
  for (const area of areas) {
    if (normalizedCity) {
      const cityMatches =
        area.city.name.trim().toLowerCase() === normalizedCity ||
        area.city.slug.trim().toLowerCase() === normalizedCity;
      if (!cityMatches) {
        continue;
      }
    }

    if (matchesArea(area, pincode)) {
      return {
        id: area.id,
        name: area.name,
        slug: area.slug,
        cityId: area.cityId,
        cityName: area.city.name,
        pincodeRangeStart: area.pincodeRangeStart,
        pincodeRangeEnd: area.pincodeRangeEnd,
        pincode: area.pincode
      };
    }
  }

  return null;
}

export async function assertServiceablePincode(input: {
  pincode: string;
  cityId?: string;
  city?: string;
}): Promise<ServiceAreaMatch> {
  const area = await findServiceableArea(input);
  if (!area) {
    throw new Error(ACTIVE_AREA_MESSAGE);
  }
  return area;
}

export function getServiceAreaUnavailableMessage(): string {
  return ACTIVE_AREA_MESSAGE;
}
