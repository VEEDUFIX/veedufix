import type { Request, Response } from "express";
import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import { invalidatePublicCatalogCache } from "../catalog/catalog.service.js";
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
        stateId: true;
        districtId: true;
        isActive: true;
      };
    };
    assignedPincodes: { select: { pincode: true } };
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

function serializeArea(area: AdminServiceAreaInclude & {
  _count?: {
    serviceAssignments: number;
    workerAssignments: number;
    categoryAssignments: number;
    subcategoryAssignments: number;
    variantAssignments: number;
  };
}) {
  return {
    id: area.id,
    cityId: area.cityId,
    city: area.city,
    name: area.name,
    slug: area.slug,
    pincode: area.pincode,
    pincodeRangeStart: area.pincodeRangeStart,
    pincodeRangeEnd: area.pincodeRangeEnd,
    pincodes: area.assignedPincodes.map((item: { pincode: string }) => item.pincode),
    isActive: area.isActive,
    createdAt: area.createdAt,
    updatedAt: area.updatedAt,
    coverageCounts: {
      services: area._count?.serviceAssignments ?? 0,
      partners: area._count?.workerAssignments ?? 0,
      categories: area._count?.categoryAssignments ?? 0,
      subcategories: area._count?.subcategoryAssignments ?? 0,
      variants: area._count?.variantAssignments ?? 0
    }
  };
}

function slugifyMarket(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

async function ensureNormalizedGeography(
  tx: Prisma.TransactionClient,
  stateName: string,
  districtName?: string | null
): Promise<{ stateId: string; districtId: string | null }> {
  const normalizedStateName = stateName.trim();
  const state = await tx.geoState.upsert({
    where: { name: normalizedStateName },
    update: {},
    create: { name: normalizedStateName }
  });
  const normalizedDistrictName = districtName?.trim();
  if (!normalizedDistrictName) {
    return { stateId: state.id, districtId: null };
  }
  const district = await tx.geoDistrict.upsert({
    where: {
      stateId_name: { stateId: state.id, name: normalizedDistrictName }
    },
    update: {},
    create: { stateId: state.id, name: normalizedDistrictName }
  });
  return { stateId: state.id, districtId: district.id };
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
    const city = await prisma.$transaction(async (tx) => {
      const geography = await ensureNormalizedGeography(tx, body.state, body.district);
      return tx.city.create({
        data: {
          name: body.name,
          state: body.state,
          district: body.district,
          ...geography,
          country: "India",
          slug: slugifyMarket(body.slug ?? body.name),
          isActive: body.isActive
        },
        select: { id: true, name: true, state: true, district: true, stateId: true, districtId: true, slug: true, isActive: true }
      });
    });
    await invalidatePublicCatalogCache();
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
    const city = await prisma.$transaction(async (tx) => {
      const id = String(request.params.id);
      const existing = await tx.city.findUnique({
        where: { id },
        select: { state: true, district: true }
      });
      if (!existing) throw AppError.notFound("Market not found");
      if (
        body.state !== undefined &&
        body.state.trim() !== existing.state.trim() &&
        body.district === undefined
      ) {
        throw AppError.badRequest("Provide the district when changing the market state");
      }
      const state = body.state ?? existing.state;
      const district = body.district ?? existing.district;
      const geography = await ensureNormalizedGeography(tx, state, district);
      return tx.city.update({
        where: { id },
        data: { ...data, ...geography },
        select: { id: true, name: true, state: true, district: true, stateId: true, districtId: true, slug: true, isActive: true }
      });
    });
    await invalidatePublicCatalogCache();
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
    select: {
      id: true,
      name: true,
      state: true,
      district: true,
      stateId: true,
      districtId: true,
      slug: true,
      serviceAreas: {
        where: { isActive: true },
        select: {
          id: true,
          name: true,
          pincode: true,
          pincodeRangeStart: true,
          pincodeRangeEnd: true,
          assignedPincodes: { select: { pincode: true } }
        },
        orderBy: { name: "asc" }
      }
    },
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
        stateId: true,
        districtId: true,
        isActive: true
      },
      orderBy: { name: "asc" }
    }),
    prisma.serviceArea.findMany({
      where: cityId ? { cityId } : undefined,
      include: {
        assignedPincodes: { select: { pincode: true } },
        _count: {
          select: {
            serviceAssignments: true,
            workerAssignments: true,
            categoryAssignments: true,
            subcategoryAssignments: true,
            variantAssignments: true
          }
        },
        city: {
          select: {
            id: true,
            name: true,
            slug: true,
            state: true,
            district: true,
            stateId: true,
            districtId: true,
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

export async function getWorkerServiceAreasHandler(request: Request, response: Response): Promise<void> {
  const workerProfileId = String(request.params.workerProfileId);
  const [worker, areas] = await Promise.all([
    prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: {
        id: true,
        fullName: true,
        displayName: true,
        user: { select: { name: true } },
        serviceAreaAssignments: {
          include: {
            serviceArea: {
              include: {
                assignedPincodes: { select: { pincode: true } },
                city: { select: { id: true, name: true, slug: true, isActive: true, stateId: true, districtId: true, state: true, district: true } }
              }
            }
          },
          orderBy: { serviceAreaId: "asc" }
        }
      }
    }),
    prisma.serviceArea.findMany({
      where: { isActive: true, city: { isActive: true } },
      include: {
        assignedPincodes: { select: { pincode: true } },
        city: { select: { id: true, name: true, slug: true, isActive: true, stateId: true, districtId: true, state: true, district: true } }
      },
      orderBy: [{ city: { state: "asc" } }, { city: { district: "asc" } }, { city: { name: "asc" } }, { name: "asc" }]
    })
  ]);
  if (!worker) {
    response.status(404).json({ message: "Partner profile not found" });
    return;
  }
  response.status(200).json({
    worker: {
      id: worker.id,
      name: worker.displayName ?? worker.fullName ?? worker.user.name
    },
    assignedAreaIds: worker.serviceAreaAssignments.map(
      (assignment: { serviceAreaId: string; serviceArea: AdminServiceAreaInclude }) => assignment.serviceAreaId
    ),
    assignedAreas: worker.serviceAreaAssignments.map(
      (assignment: { serviceAreaId: string; serviceArea: AdminServiceAreaInclude }) => serializeArea(assignment.serviceArea)
    ),
    areas: areas.map((area) => serializeArea(area))
  });
}

export async function updateWorkerServiceAreasHandler(request: Request, response: Response): Promise<void> {
  const workerProfileId = String(request.params.workerProfileId);
  const { serviceAreaIds } = request.body as { serviceAreaIds: string[] };
  const areas = await prisma.serviceArea.findMany({
    where: { id: { in: serviceAreaIds }, isActive: true, city: { isActive: true } },
    select: { id: true, cityId: true, name: true, city: { select: { name: true } } }
  });
  if (areas.length !== serviceAreaIds.length) {
    response.status(400).json({ message: "Every assigned Partner area must be active and configured" });
    return;
  }
  try {
    await prisma.$transaction(async (tx) => {
      await tx.workerProfile.findUniqueOrThrow({ where: { id: workerProfileId }, select: { id: true } });
      await tx.workerProfileServiceArea.deleteMany({ where: { workerProfileId } });
      await tx.workerProfileServiceArea.createMany({
        data: serviceAreaIds.map((serviceAreaId) => ({ workerProfileId, serviceAreaId }))
      });
      const cityIds = [...new Set(areas.map((area) => area.cityId))];
      const cityNames = [...new Set(areas.map((area) => area.city.name))];
      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: {
          ...(areas.length > 0
            ? {
                cityId: cityIds.length === 1 ? cityIds[0] : null,
                city: cityNames.join(", ").slice(0, 120)
              }
            : {}),
          serviceAreas: areas.map((area) => area.name).join(", ").slice(0, 500)
        }
      });
    });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2025") {
      response.status(404).json({ message: "Partner profile not found" });
      return;
    }
    throw error;
  }
  response.status(200).json({ ok: true, workerProfileId, serviceAreaIds });
}

export async function createServiceAreaHandler(request: Request, response: Response): Promise<void> {
  const body = request.body as {
    cityId: string;
    name: string;
    slug?: string;
    pincode?: string | null;
    pincodes?: string[];
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
        assignedPincodes: body.pincodes?.length
          ? {
              create: body.pincodes.map((pincode) => ({
                pincodeRecord: {
                  connectOrCreate: {
                    where: { code: pincode },
                    create: { code: pincode }
                  }
                }
              }))
            }
          : undefined,
        pincodeRangeStart: body.pincodeRangeStart ?? null,
        pincodeRangeEnd: body.pincodeRangeEnd ?? null,
        isActive: body.isActive ?? true
      },
      include: {
        assignedPincodes: { select: { pincode: true } },
        city: {
          select: {
            id: true,
            name: true,
            slug: true,
            state: true,
            district: true,
            stateId: true,
            districtId: true,
            isActive: true
          }
        }
      }
    });

    await invalidatePublicCatalogCache();
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
    pincodes?: string[];
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
    const serviceArea = await prisma.$transaction(async (tx) => {
      const id = String(request.params.id);
      const hasCoverageInput =
        body.pincode !== undefined ||
        body.pincodes !== undefined ||
        body.pincodeRangeStart !== undefined ||
        body.pincodeRangeEnd !== undefined;
      let pincodesToReplace: string[] | undefined;

      if (hasCoverageInput) {
        const existing = await tx.serviceArea.findUnique({
          where: { id },
          select: {
            pincode: true,
            pincodeRangeStart: true,
            pincodeRangeEnd: true,
            assignedPincodes: { select: { pincode: true } }
          }
        });
        if (!existing) throw AppError.notFound("Service area not found");

        const requestedExact = Boolean(body.pincode) || Boolean(body.pincodes?.length);
        const legacyPincode =
          body.pincodes !== undefined &&
          existing.pincode !== null &&
          !body.pincodes.includes(existing.pincode)
            ? null
            : existing.pincode;
        const requestedRange =
          Boolean(body.pincodeRangeStart) || Boolean(body.pincodeRangeEnd);
        if (requestedExact && requestedRange) {
          throw AppError.badRequest("Use exact pincodes or a pincode range, not both");
        }

        if (requestedRange) {
          if (!body.pincodeRangeStart || !body.pincodeRangeEnd) {
            throw AppError.badRequest(
              "Both pincode range start and end are required together"
            );
          }
          data.pincode = null;
          data.pincodeRangeStart = body.pincodeRangeStart;
          data.pincodeRangeEnd = body.pincodeRangeEnd;
          pincodesToReplace = [];
        } else if (requestedExact) {
          data.pincode =
            body.pincode !== undefined ? body.pincode : legacyPincode;
          data.pincodeRangeStart = null;
          data.pincodeRangeEnd = null;
          if (body.pincodes !== undefined) {
            pincodesToReplace = body.pincodes;
          } else if (
            existing.pincode &&
            body.pincode !== undefined &&
            body.pincode !== existing.pincode
          ) {
            pincodesToReplace = existing.assignedPincodes
              .map((assignment: { pincode: string }) => assignment.pincode)
              .filter((code: string) => code !== existing.pincode);
          }
        } else {
          const currentRangeIsValid = Boolean(
            existing.pincodeRangeStart && existing.pincodeRangeEnd
          );
          const finalPincode =
            body.pincode !== undefined ? body.pincode : legacyPincode;
          const currentAssignments = existing.assignedPincodes.map(
            (assignment: { pincode: string }) => assignment.pincode
          );
          const changedLegacyPincode =
            body.pincode !== undefined && body.pincode !== existing.pincode;
          const finalPincodes =
            body.pincodes ??
            (changedLegacyPincode && existing.pincode
              ? currentAssignments.filter((code: string) => code !== existing.pincode)
              : currentAssignments);

          const clearsRange =
            body.pincodeRangeStart !== undefined || body.pincodeRangeEnd !== undefined;
          if (currentRangeIsValid && !clearsRange) {
            // Clearing the exact-pincode list alone should not erase a configured range.
            data.pincode = null;
            data.pincodeRangeStart = existing.pincodeRangeStart;
            data.pincodeRangeEnd = existing.pincodeRangeEnd;
            pincodesToReplace = [];
          } else {
            if (!finalPincode && finalPincodes.length === 0) {
              throw AppError.badRequest(
                "A service area must retain at least one exact pincode or a complete range"
              );
            }
            data.pincode = finalPincode;
            data.pincodeRangeStart = null;
            data.pincodeRangeEnd = null;
            if (body.pincodes !== undefined || changedLegacyPincode) {
              pincodesToReplace = finalPincodes;
            }
          }
        }
      }

      await tx.serviceArea.update({ where: { id }, data });
      if (pincodesToReplace !== undefined) {
        await tx.serviceAreaPincode.deleteMany({ where: { serviceAreaId: id } });
        if (pincodesToReplace.length > 0) {
          await tx.geoPincode.createMany({
            data: pincodesToReplace.map((code) => ({ code })),
            skipDuplicates: true
          });
          const pincodeRecords = await tx.geoPincode.findMany({
            where: { code: { in: pincodesToReplace } },
            select: { id: true, code: true }
          });
          await tx.serviceAreaPincode.createMany({
            data: pincodeRecords.map((record) => ({
              serviceAreaId: id,
              pincode: record.code,
              pincodeId: record.id
            }))
          });
        }
      }
      return tx.serviceArea.findUniqueOrThrow({
        where: { id },
        include: {
          assignedPincodes: { select: { pincode: true } },
          city: {
            select: {
              id: true,
              name: true,
              slug: true,
              state: true,
              district: true,
              stateId: true,
              districtId: true,
              isActive: true
            }
          }
        }
      });
    });

    await invalidatePublicCatalogCache();
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
    await invalidatePublicCatalogCache();
    response.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2025") {
      response.status(404).json({ message: "Service area not found" });
      return;
    }

    throw error;
  }
}
