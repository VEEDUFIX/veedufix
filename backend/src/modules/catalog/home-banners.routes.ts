import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../lib/prisma.js";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { catalogService, publicServiceEligibility } from "./catalog.service.js";

const destinationTypes = ["service", "category", "offer", "search", "custom_route"] as const;

const bannerFields = {
  imageUrl: z.string().url().max(2048).refine((value) => value.startsWith("https://"), "Image URL must use HTTPS"),
  isActive: z.boolean().optional(),
  sortOrder: z.number().int().min(0).max(10000).optional(),
  destinationType: z.enum(destinationTypes),
  destinationValue: z.string().trim().min(1).max(512),
  startsAt: z.string().datetime().nullable().optional(),
  endsAt: z.string().datetime().nullable().optional(),
};

function validateDestination(
  value: { destinationType?: string; destinationValue?: string },
  context: z.RefinementCtx,
) {
  if (value.destinationType === "custom_route" && value.destinationValue) {
    const route = value.destinationValue.trim();
    if (
      !route.startsWith("/") ||
      route.startsWith("//") ||
      route.includes("\\") ||
      /[\r\n]/.test(route)
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Custom destinations must be internal app routes",
        path: ["destinationValue"],
      });
    }
  }
}

async function destinationTargetExists(
  destinationType: string,
  destinationValue: string,
): Promise<boolean> {
  if (destinationType === "service") {
    return (await prisma.service.findFirst({
      where: { slug: destinationValue, ...publicServiceEligibility() },
      select: { id: true },
    })) != null;
  }
  if (destinationType === "category") {
    return (await prisma.serviceCategory.findFirst({
      where: { slug: destinationValue, isActive: true },
      select: { id: true },
    })) != null;
  }
  if (destinationType === "custom_route") {
    return destinationValue.startsWith("/") &&
      !destinationValue.startsWith("//") &&
      !destinationValue.includes("\\") &&
      !/[\r\n]/.test(destinationValue);
  }
  return true;
}

const createBannerSchema = z.object({
  body: z.object(bannerFields).superRefine(validateDestination).refine(
    (value) => !value.startsAt || !value.endsAt || Date.parse(value.startsAt) <= Date.parse(value.endsAt),
    { message: "Start date must be before end date", path: ["endsAt"] },
  ),
});

const updateBannerSchema = z.object({
  body: z.object(bannerFields).partial().superRefine(validateDestination).refine(
    (value) => !value.startsAt || !value.endsAt || Date.parse(value.startsAt) <= Date.parse(value.endsAt),
    { message: "Start date must be before end date", path: ["endsAt"] },
  ),
});

const internalDestination = z.string().trim().min(1).max(512).refine(
  (value) => value.startsWith("/") &&
    !value.startsWith("//") &&
    !value.includes("\\") &&
    !/[\r\n]/.test(value),
  "See-all destination must be an internal app route",
);

const serviceIdsArraySchema = z.array(z.string().min(1)).max(30);
const uniqueServiceIdsSchema = serviceIdsArraySchema.refine(
  (ids) => new Set(ids).size === ids.length,
  "A service can only be added once to a section",
);

const createHomeSectionSchema = z.object({
  body: z.object({
    title: z.string().trim().min(2).max(120),
    subtitle: z.string().trim().max(240).nullable().optional(),
    sortOrder: z.number().int().min(0).max(10000).optional(),
    isActive: z.boolean().optional(),
    seeAllDestination: internalDestination.optional(),
    serviceIds: serviceIdsArraySchema.min(1).refine(
      (ids) => new Set(ids).size === ids.length,
      "A service can only be added once to a section",
    ),
  }),
});

const updateHomeSectionSchema = z.object({
  body: z.object({
    title: z.string().trim().min(2).max(120).optional(),
    subtitle: z.string().trim().max(240).nullable().optional(),
    sortOrder: z.number().int().min(0).max(10000).optional(),
    isActive: z.boolean().optional(),
    seeAllDestination: internalDestination.optional(),
    serviceIds: uniqueServiceIdsSchema.optional(),
  }),
});

const homeSectionAdminInclude = {
  items: {
    orderBy: [{ sortOrder: "asc" as const }],
    include: {
      service: {
        select: {
          id: true,
          name: true,
          slug: true,
          isActive: true,
          category: { select: { name: true } },
        },
      },
    },
  },
};

async function validateHomeSectionServices(serviceIds: string[]): Promise<boolean> {
  if (serviceIds.length === 0) return true;
  const count = await prisma.service.count({
    where: { id: { in: serviceIds } },
  });
  return count === serviceIds.length;
}

export const homeBannersRouter = Router();
export const adminHomeBannersRouter = Router();

homeBannersRouter.get("/home-banners", async (_request, response) => {
  const now = new Date();
  const banners = await prisma.homeBanner.findMany({
    where: {
      isActive: true,
      AND: [
        { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
        { OR: [{ endsAt: null }, { endsAt: { gt: now } }] },
      ],
    },
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    select: {
      id: true,
      imageUrl: true,
      sortOrder: true,
      destinationType: true,
      destinationValue: true,
    },
  });
  response.status(200).json({ banners });
});

homeBannersRouter.get("/home-sections", async (request, response) => {
  const { cityId } = request.query as { cityId?: string };
  const sections = await catalogService.resolveHomeServiceSections(cityId);
  response.status(200).json({ sections });
});

adminHomeBannersRouter.use(requireAuth, requireRole("ADMIN"));

adminHomeBannersRouter.get("/home-section-services", async (_request, response) => {
  const services = await prisma.service.findMany({
    where: { isActive: true },
    select: {
      id: true,
      name: true,
      slug: true,
      category: { select: { name: true } },
    },
    orderBy: [{ category: { name: "asc" } }, { sortOrder: "asc" }, { name: "asc" }],
  });
  response.status(200).json({ services });
});

adminHomeBannersRouter.get("/home-sections", async (_request, response) => {
  const sections = await prisma.homeServiceSection.findMany({
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    include: homeSectionAdminInclude,
  });
  response.status(200).json({ sections });
});

adminHomeBannersRouter.post(
  "/home-sections",
  validate(createHomeSectionSchema),
  async (request, response) => {
    const body = request.body as z.infer<typeof createHomeSectionSchema>["body"];
    if (!(await validateHomeSectionServices(body.serviceIds))) {
      response.status(400).json({ message: "One or more selected services were not found" });
      return;
    }
    const section = await prisma.homeServiceSection.create({
      data: {
        title: body.title,
        subtitle: body.subtitle?.trim() || null,
        sortOrder: body.sortOrder ?? 0,
        isActive: body.isActive ?? true,
        seeAllDestination: body.seeAllDestination ?? "/search",
        items: {
          create: body.serviceIds.map((serviceId, sortOrder) => ({ serviceId, sortOrder })),
        },
      },
      include: homeSectionAdminInclude,
    });
    response.status(201).json({ section });
  },
);

adminHomeBannersRouter.patch(
  "/home-sections/:id",
  validate(updateHomeSectionSchema),
  async (request, response) => {
    const body = request.body as z.infer<typeof updateHomeSectionSchema>["body"];
    const existing = await prisma.homeServiceSection.findUnique({
      where: { id: request.params.id },
    });
    if (!existing) {
      response.status(404).json({ message: "Home section not found" });
      return;
    }
    if (body.serviceIds && !(await validateHomeSectionServices(body.serviceIds))) {
      response.status(400).json({ message: "One or more selected services were not found" });
      return;
    }

    const section = await prisma.$transaction(async (transaction) => {
      await transaction.homeServiceSection.update({
        where: { id: existing.id },
        data: {
          title: body.title,
          subtitle: body.subtitle === undefined
            ? undefined
            : body.subtitle?.trim() || null,
          sortOrder: body.sortOrder,
          isActive: body.isActive,
          seeAllDestination: body.seeAllDestination,
        },
      });
      if (body.serviceIds !== undefined) {
        await transaction.homeServiceSectionItem.deleteMany({
          where: { sectionId: existing.id },
        });
        if (body.serviceIds.length > 0) {
          await transaction.homeServiceSectionItem.createMany({
            data: body.serviceIds.map((serviceId, sortOrder) => ({
              sectionId: existing.id,
              serviceId,
              sortOrder,
            })),
          });
        }
      }
      return transaction.homeServiceSection.findUniqueOrThrow({
        where: { id: existing.id },
        include: homeSectionAdminInclude,
      });
    });
    response.status(200).json({ section });
  },
);

adminHomeBannersRouter.delete("/home-sections/:id", async (request, response) => {
  const result = await prisma.homeServiceSection.deleteMany({
    where: { id: request.params.id },
  });
  if (result.count === 0) {
    response.status(404).json({ message: "Home section not found" });
    return;
  }
  response.status(204).send();
});

adminHomeBannersRouter.get("/home-banners", async (_request, response) => {
  const banners = await prisma.homeBanner.findMany({
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
  });
  response.status(200).json({ banners });
});

adminHomeBannersRouter.post(
  "/home-banners",
  validate(createBannerSchema),
  async (request, response) => {
    const body = request.body as z.infer<typeof createBannerSchema>["body"];
    if (!(await destinationTargetExists(body.destinationType, body.destinationValue))) {
      response.status(400).json({ message: "The selected banner destination was not found" });
      return;
    }
    const banner = await prisma.homeBanner.create({
      data: {
        imageUrl: body.imageUrl,
        isActive: body.isActive ?? true,
        sortOrder: body.sortOrder ?? 0,
        destinationType: body.destinationType,
        destinationValue: body.destinationValue,
        startsAt: body.startsAt ? new Date(body.startsAt) : null,
        endsAt: body.endsAt ? new Date(body.endsAt) : null,
      },
    });
    response.status(201).json({ banner });
  },
);

adminHomeBannersRouter.patch(
  "/home-banners/:id",
  validate(updateBannerSchema),
  async (request, response) => {
    const body = request.body as z.infer<typeof updateBannerSchema>["body"];
    const existing = await prisma.homeBanner.findUnique({
      where: { id: request.params.id },
    });
    if (!existing) {
      response.status(404).json({ message: "Home banner not found" });
      return;
    }
    const startsAt = body.startsAt === undefined
      ? existing.startsAt
      : body.startsAt === null ? null : new Date(body.startsAt);
    const endsAt = body.endsAt === undefined
      ? existing.endsAt
      : body.endsAt === null ? null : new Date(body.endsAt);
    if (startsAt && endsAt && startsAt > endsAt) {
      response.status(400).json({ message: "Start date must be before end date" });
      return;
    }
    const destinationType = body.destinationType ?? existing.destinationType;
    const destinationValue = body.destinationValue ?? existing.destinationValue;
    if (!(await destinationTargetExists(destinationType, destinationValue))) {
      response.status(400).json({ message: "The selected banner destination was not found" });
      return;
    }
    const banner = await prisma.homeBanner.update({
      where: { id: existing.id },
      data: {
        ...body,
        startsAt: body.startsAt === undefined
          ? undefined
          : body.startsAt === null ? null : new Date(body.startsAt),
        endsAt: body.endsAt === undefined
          ? undefined
          : body.endsAt === null ? null : new Date(body.endsAt),
      },
    });
    response.status(200).json({ banner });
  },
);

adminHomeBannersRouter.delete("/home-banners/:id", async (request, response) => {
  const result = await prisma.homeBanner.deleteMany({
    where: { id: request.params.id },
  });
  if (result.count === 0) {
    response.status(404).json({ message: "Home banner not found" });
    return;
  }
  response.status(204).send();
});
