import type { Request, Response } from "express";
import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  findServiceableArea,
  getServiceAreaUnavailableMessage
} from "./service-area.service.js";

type AdminServiceAreaInclude = Prisma.ServiceAreaGetPayload<{
  include: {
    city: {
      select: {
        id: true;
        name: true;
        slug: true;
        state: true;
        district: true;
        isActive: true;
      };
    };
  };
}>;

function slugifyArea(value: string): string {
  const slug = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-{2,}/g, "-");

  return slug || "service-area";
}

function serializeArea(area: AdminServiceAreaInclude) {
  return {
    id: area.id,
    cityId: area.cityId,
    city: area.city,
    name: area.name,
    slug: area.slug,
    pincode: area.pincode,
    pincodeRangeStart: area.pincodeRangeStart,
    pincodeRangeEnd: area.pincodeRangeEnd,
    isActive: area.isActive,
    createdAt: area.createdAt,
    updatedAt: area.updatedAt
  };
}

function slugifyMarket(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

export async function createMarketHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  const body = request.body as {
    name: string;
    state: string;
    district: string;
    slug?: string;
    isActive: boolean;
  };
  try {
    const city = await prisma.city.create({
      data: {
        name: body.name,
        state: body.state,
        district: body.district,
        country: "India",
        slug: slugifyMarket(body.slug ?? body.name),
        isActive: body.isActive
      },
      select: { id: true, name: true, state: true, district: true, slug: true, isActive: true }
    });
    response.status(201).json({ city });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      response.status(409).json({ message: "A market with that city name or slug already exists" });
      return;
    }
    throw error;
  }
}

export async function updateMarketHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  const body = request.body as {
    name?: string;
    state?: string;
    district?: string;
    slug?: string;
    isActive?: boolean;
  };
  const data: {
    name?: string;
    state?: string;
    district?: string;
    slug?: string;
    isActive?: boolean;
  } = {};
  if (body.name !== undefined) data.name = body.name;
  if (body.state !== undefined) data.state = body.state;
  if (body.district !== undefined) data.district = body.district;
  if (body.slug !== undefined || body.name !== undefined) {
    data.slug = slugifyMarket(body.slug ?? body.name ?? "");
  }
  if (body.isActive !== undefined) data.isActive = body.isActive;

  try {
    const city = await prisma.city.update({
      where: { id: String(request.params.id) },
      data,
      select: { id: true, name: true, state: true, district: true, slug: true, isActive: true }
    });
    response.status(200).json({ city });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === "P2025") {
        response.status(404).json({ message: "Market not found" });
        return;
      }
      if (error.code === "P2002") {
        response.status(409).json({ message: "A market with that city name or slug already exists" });
        return;
      }
    }
    throw error;
  }
}

export async function checkServiceAreaHandler(request: Request, response: Response): Promise<void> {
  const pincode = String(request.query.pincode ?? "");
  const cityId = typeof request.query.cityId === "string" ? request.query.cityId : undefined;
  const city = typeof request.query.city === "string" ? request.query.city : undefined;

  const area = await findServiceableArea({ pincode, cityId, city });
  if (!area) {
    response.status(200).json({
      serviceable: false,
      message: getServiceAreaUnavailableMessage()
    });
    return;
  }

  response.status(200).json({
    serviceable: true,
    area
  });
}

export async function listAvailableCitiesHandler(_request: Request, response: Response): Promise<void> {
  const cities = await prisma.city.findMany({
    where: {
      isActive: true,
      serviceAreas: { some: { isActive: true } }
    },
    select: { id: true, name: true, state: true, district: true, slug: true },
    orderBy: [{ state: "asc" }, { district: "asc" }, { name: "asc" }]
  });
  response.status(200).json({ cities });
}

export async function listServiceAreasHandler(request: Request, response: Response): Promise<void> {
  const cityId = typeof request.query.cityId === "string" ? request.query.cityId : undefined;

  const [cities, serviceAreas] = await Promise.all([
    prisma.city.findMany({
      select: {
        id: true,
        name: true,
        slug: true,
        state: true,
        district: true,
        isActive: true
      },
      orderBy: { name: "asc" }
    }),
    prisma.serviceArea.findMany({
      where: cityId ? { cityId } : undefined,
      include: {
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
      orderBy: [{ cityId: "asc" }, { name: "asc" }]
    })
  ]);

  response.status(200).json({
    cities,
    serviceAreas: serviceAreas.map(serializeArea)
  });
}

export async function createServiceAreaHandler(request: Request, response: Response): Promise<void> {
  const body = request.body as {
    cityId: string;
    name: string;
    slug?: string;
    pincode?: string | null;
    pincodeRangeStart?: string | null;
    pincodeRangeEnd?: string | null;
    isActive?: boolean;
  };

  const slug = slugifyArea(body.slug ?? body.name);

  try {
    const serviceArea = await prisma.serviceArea.create({
      data: {
        cityId: body.cityId,
        name: body.name.trim(),
        slug,
        pincode: body.pincode ?? null,
        pincodeRangeStart: body.pincodeRangeStart ?? null,
        pincodeRangeEnd: body.pincodeRangeEnd ?? null,
        isActive: body.isActive ?? true
      },
      include: {
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
      }
    });

    response.status(201).json({ serviceArea: serializeArea(serviceArea) });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      response.status(409).json({ message: "A service area with that slug already exists for the selected city" });
      return;
    }

    throw error;
  }
}

export async function updateServiceAreaHandler(request: Request, response: Response): Promise<void> {
  const body = request.body as {
    cityId?: string;
    name?: string;
    slug?: string;
    pincode?: string | null;
    pincodeRangeStart?: string | null;
    pincodeRangeEnd?: string | null;
    isActive?: boolean;
  };

  const data: Prisma.ServiceAreaUpdateInput = {};
  if (body.cityId !== undefined) data.city = { connect: { id: body.cityId } };
  if (body.name !== undefined) data.name = body.name.trim();
  if (body.slug !== undefined || body.name !== undefined) {
    data.slug = slugifyArea(body.slug ?? body.name ?? "");
  }
  if (body.pincode !== undefined) data.pincode = body.pincode;
  if (body.pincodeRangeStart !== undefined) data.pincodeRangeStart = body.pincodeRangeStart;
  if (body.pincodeRangeEnd !== undefined) data.pincodeRangeEnd = body.pincodeRangeEnd;
  if (body.isActive !== undefined) data.isActive = body.isActive;

  try {
    const serviceArea = await prisma.serviceArea.update({
      where: { id: String(request.params.id) },
      data,
      include: {
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
      }
    });

    response.status(200).json({ serviceArea: serializeArea(serviceArea) });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === "P2025") {
        response.status(404).json({ message: "Service area not found" });
        return;
      }
      if (error.code === "P2002") {
        response.status(409).json({ message: "A service area with that slug already exists for the selected city" });
        return;
      }
    }

    throw error;
  }
}

export async function deleteServiceAreaHandler(request: Request, response: Response): Promise<void> {
  try {
    await prisma.serviceArea.delete({
      where: { id: String(request.params.id) }
    });
    response.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2025") {
      response.status(404).json({ message: "Service area not found" });
      return;
    }

    throw error;
  }
}
