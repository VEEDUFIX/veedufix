import { Prisma, PriceRuleType } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { redis } from "../../lib/redis.js";

type LocaleInput = {
  locale?: string;
  cityId?: string;
};

type PublicCatalogFilter = LocaleInput & {
  q?: string;
  categorySlug?: string;
  subcategorySlug?: string;
  page?: number;
  pageSize?: number;
  includeInactive?: boolean;
};

type CatalogNode = {
  name: string;
  slug: string;
  description?: string | null;
  iconUrl?: string | null;
  seoTitle?: string | null;
  seoDescription?: string | null;
  sortOrder?: number;
  isActive?: boolean;
  featured?: boolean;
  popular?: boolean;
  translations?: Array<{
    locale: string;
    name: string;
    description?: string;
    shortDescription?: string;
    seoTitle?: string;
    seoDescription?: string;
  }>;
};

const CATALOG_CACHE_TTL_SECONDS = 600;
const CATALOG_CACHE_VERSION_KEY = "cache:catalog:version";

async function getCatalogCacheVersion(): Promise<number> {
  // Redis is a performance optimization only - any Redis failure must degrade to direct DB access, never fail the request.
  try {
    const rawVersion = await redis.get(CATALOG_CACHE_VERSION_KEY);
    const version = Number(rawVersion ?? "1");
    return Number.isFinite(version) && version > 0 ? version : 1;
  } catch (error) {
    logger.error(
      {
        error,
        operation: "redis.get",
        key: CATALOG_CACHE_VERSION_KEY
      },
      "Catalog cache version lookup failed"
    );
    return 1;
  }
}

async function invalidateCatalogCache(): Promise<void> {
  // Redis is a performance optimization only - any Redis failure must degrade to direct DB access, never fail the request.
  try {
    await redis.incr(CATALOG_CACHE_VERSION_KEY);
  } catch (error) {
    logger.error(
      {
        error,
        operation: "redis.incr",
        key: CATALOG_CACHE_VERSION_KEY
      },
      "Catalog cache invalidation failed"
    );
  }
}

function buildCatalogCacheKey(version: number, scope: string, parts: Array<string | null | undefined>): string {
  return ["catalog", `v${version}`, scope, ...parts.map((part) => part ?? "all")].join(":");
}

async function readCatalogCache<T>(
  scope: string,
  parts: Array<string | null | undefined>,
  loader: () => Promise<T>
): Promise<T> {
  // Redis is a performance optimization only - any Redis failure must degrade to direct DB access, never fail the request.
  const version = await getCatalogCacheVersion();
  const cacheKey = buildCatalogCacheKey(version, scope, parts);
  let cached: string | null = null;
  try {
    cached = await redis.get(cacheKey);
  } catch (error) {
    logger.error(
      {
        error,
        operation: "redis.get",
        key: cacheKey
      },
      "Catalog cache read failed"
    );
  }

  if (cached) {
    try {
      return JSON.parse(cached) as T;
    } catch (error) {
      logger.error(
        {
          error,
          operation: "json.parse",
          key: cacheKey
        },
        "Catalog cache parse failed"
      );
    }
  }

  const value = await loader();
  try {
    await redis.set(cacheKey, JSON.stringify(value), "EX", CATALOG_CACHE_TTL_SECONDS);
  } catch (error) {
    logger.error(
      {
        error,
        operation: "redis.set",
        key: cacheKey
      },
      "Catalog cache write failed"
    );
  }
  return value;
}

function slugify(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function uniqueCode(prefix: string, name: string): string {
  const base = slugify(name).replace(/-/g, "").slice(0, 18).toUpperCase();
  const suffix = Math.random().toString(36).slice(2, 6).toUpperCase();
  return `${prefix}-${base || "SERVICE"}-${suffix}`;
}

function normalizeSacCode(value?: string | null): string {
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : "PENDING";
}

async function resolveSkillId(name: string, slug?: string) {
  const skillSlug = slug ? slugify(slug) : slugify(name);
  const existing = await prisma.skill.findUnique({ where: { slug: skillSlug } });
  if (existing) {
    return existing.id;
  }

  const skill = await prisma.skill.create({
    data: {
      name,
      slug: skillSlug
    }
  });

  return skill.id;
}

async function resolveToolId(name: string, slug?: string) {
  const toolSlug = slug ? slugify(slug) : slugify(name);
  const existing = await prisma.tool.findUnique({ where: { slug: toolSlug } });
  if (existing) {
    return existing.id;
  }

  const tool = await prisma.tool.create({
    data: {
      name,
      slug: toolSlug
    }
  });

  return tool.id;
}

async function ensureUniqueSlug(
  finder: (slug: string) => Promise<{ id: string } | null>,
  rawSlug: string
): Promise<string> {
  let candidate = rawSlug;
  let attempt = 1;
  while (await finder(candidate)) {
    attempt += 1;
    candidate = `${rawSlug}-${attempt}`;
  }
  return candidate;
}

function catalogInclude(cityId?: string) {
  return {
    translations: true,
    subcategories: {
      where: { isActive: true },
      orderBy: [{ sortOrder: "asc" as const }, { name: "asc" as const }],
      include: {
        translations: true,
        _count: {
          select: {
            catalogServices: true
          }
        }
      }
    },
    _count: {
      select: {
        services: true,
        subcategories: true
      }
    }
  } satisfies Prisma.ServiceCategoryInclude;
}

function serviceInclude(cityId?: string) {
  return {
    translations: true,
    images: {
      orderBy: [{ sortOrder: "asc" as const }, { createdAt: "asc" as const }]
    },
    requiredSkills: {
      include: { skill: true },
      orderBy: [{ sortOrder: "asc" as const }, { createdAt: "asc" as const }]
    },
    requiredTools: {
      include: { tool: true },
      orderBy: [{ sortOrder: "asc" as const }, { createdAt: "asc" as const }]
    },
    requiredDocuments: {
      orderBy: [{ sortOrder: "asc" as const }, { createdAt: "asc" as const }]
    },
    pricingRules: {
      where: cityId
        ? {
            isActive: true,
            OR: [{ cityId: null }, { cityId }]
          }
        : { isActive: true },
      orderBy: [{ priority: "desc" as const }, { createdAt: "desc" as const }]
    },
    category: {
      include: { translations: true }
    },
    subcategory: {
      include: { translations: true }
    }
  } satisfies Prisma.ServiceInclude;
}

function applyCatalogNodeTranslations<T extends CatalogNode>(item: T): T {
  return item;
}

function pickBaseServicePrice(service: {
  startingPrice: Prisma.Decimal;
  pricingRules: Array<{
    cityId: string | null;
    type: string;
    price: Prisma.Decimal;
    priority: number;
  }>;
  categoryId: string;
  subcategoryId: string;
}) {
  const directRule = service.pricingRules.find((rule) => rule.type === "BASE") ?? service.pricingRules[0];
  return directRule ? directRule.price : service.startingPrice;
}

async function resolveCatalogTree(cityId?: string, locale?: string, includeInactive = false) {
  const where = includeInactive ? {} : { isActive: true };
  return readCatalogCache("tree", [cityId, locale, includeInactive ? "inactive" : "active"], async () =>
    prisma.serviceCategory.findMany({
      where,
      orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
      include: {
        ...catalogInclude(cityId)
      }
    })
  );
}

async function resolveServiceBySlug(slug: string, cityId?: string) {
  return readCatalogCache("service", [slug, cityId], async () =>
    prisma.service.findUnique({
      where: { slug },
      include: serviceInclude(cityId)
    })
  );
}

async function resolveCategoryBySlug(slug: string) {
  return readCatalogCache("category", [slug], async () =>
    prisma.serviceCategory.findUnique({
      where: { slug },
      include: {
        translations: true,
        subcategories: {
          orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
          include: {
            translations: true,
            catalogServices: {
              where: { isActive: true },
              orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
              include: {
                translations: true,
                images: {
                  orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }]
                }
              }
            }
          }
        }
      }
    })
  );
}

async function resolveSubcategoryBySlug(slug: string) {
  return readCatalogCache("subcategory", [slug], async () =>
    prisma.serviceSubcategory.findUnique({
      where: { slug },
      include: {
        translations: true,
        category: { include: { translations: true } },
        catalogServices: {
          where: { isActive: true },
          orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
          include: {
            translations: true,
            images: {
              orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }]
            }
          }
        }
      }
    })
  );
}

async function searchCatalog(input: PublicCatalogFilter) {
  const where: Prisma.ServiceWhereInput = {
    isActive: input.includeInactive ? undefined : true,
    ...(input.categorySlug
      ? {
          category: {
            is: {
              slug: input.categorySlug
            }
          }
        }
      : {}),
    ...(input.subcategorySlug
      ? {
          subcategory: {
            is: {
              slug: input.subcategorySlug
            }
          }
        }
      : {}),
    OR: input.q
      ? [
          { name: { contains: input.q, mode: "insensitive" as const } },
          { slug: { contains: input.q, mode: "insensitive" as const } },
          { code: { contains: input.q, mode: "insensitive" as const } },
          { description: { contains: input.q, mode: "insensitive" as const } },
          { shortDescription: { contains: input.q, mode: "insensitive" as const } },
          {
            category: {
              OR: [
                { name: { contains: input.q, mode: "insensitive" as const } },
                { slug: { contains: input.q, mode: "insensitive" as const } }
              ]
            }
          },
          {
            subcategory: {
              OR: [
                { name: { contains: input.q, mode: "insensitive" as const } },
                { slug: { contains: input.q, mode: "insensitive" as const } }
              ]
            }
          },
          {
            searchKeywords: {
              some: {
                keyword: { contains: input.q, mode: "insensitive" as const }
              }
            }
          }
        ]
      : undefined
  };

  const [items, total] = await Promise.all([
    prisma.service.findMany({
      where,
      take: input.pageSize ?? 20,
      skip: ((input.page ?? 1) - 1) * (input.pageSize ?? 20),
      orderBy: [{ featured: "desc" }, { popular: "desc" }, { reviewCount: "desc" }, { sortOrder: "asc" }],
      include: serviceInclude(input.cityId)
    }),
    prisma.service.count({ where })
  ]);

  return { items, total };
}

async function getAutocompleteSuggestions(query: string, limit: number, cityId?: string) {
  const [services, categories, subcategories] = await readCatalogCache("autocomplete", [query, String(limit), cityId], async () =>
    Promise.all([
      prisma.service.findMany({
        where: {
          isActive: true,
          OR: [
            { name: { contains: query, mode: "insensitive" } },
            { code: { contains: query, mode: "insensitive" } },
            { slug: { contains: query, mode: "insensitive" } }
          ]
        },
        take: limit,
        orderBy: [{ popular: "desc" }, { reviewCount: "desc" }],
        select: {
          name: true,
          slug: true,
          category: { select: { slug: true } },
          subcategory: { select: { slug: true } }
        }
      }),
      prisma.serviceCategory.findMany({
        where: {
          isActive: true,
          OR: [
            { name: { contains: query, mode: "insensitive" } },
            { slug: { contains: query, mode: "insensitive" } }
          ]
        },
        take: limit,
        orderBy: [{ popular: "desc" }, { sortOrder: "asc" }],
        select: { name: true, slug: true }
      }),
      prisma.serviceSubcategory.findMany({
        where: {
          isActive: true,
          OR: [
            { name: { contains: query, mode: "insensitive" } },
            { slug: { contains: query, mode: "insensitive" } }
          ]
        },
        take: limit,
        orderBy: [{ rating: "desc" }, { sortOrder: "asc" }],
        select: {
          name: true,
          slug: true,
          category: { select: { slug: true } }
        }
      })
    ])
  );

  return {
    services: services.map((item) => ({
      label: item.name,
      kind: "SERVICE",
      slug: item.slug,
      categorySlug: item.category.slug,
      subcategorySlug: item.subcategory.slug
    })),
    categories: categories.map((item) => ({
      label: item.name,
      kind: "CATEGORY",
      slug: item.slug
    })),
    subcategories: subcategories.map((item) => ({
      label: item.name,
      kind: "SUBCATEGORY",
      slug: item.slug,
      categorySlug: item.category.slug
    }))
  };
}

async function getHomeCatalogSections(cityId?: string) {
  return readCatalogCache("home-sections", [cityId], async () => {
    const [featuredServices, popularServices, trendingServices, recommendedServices] = await Promise.all([
      prisma.service.findMany({
        where: { isActive: true, featured: true },
        take: 8,
        orderBy: [{ sortOrder: "asc" }, { reviewCount: "desc" }],
        include: serviceInclude(cityId)
      }),
      prisma.service.findMany({
        where: { isActive: true, popular: true },
        take: 8,
        orderBy: [{ reviewCount: "desc" }, { rating: "desc" }],
        include: serviceInclude(cityId)
      }),
      prisma.service.findMany({
        where: { isActive: true },
        take: 8,
        orderBy: [{ reviewCount: "desc" }, { updatedAt: "desc" }],
        include: serviceInclude(cityId)
      }),
      prisma.service.findMany({
        where: { isActive: true, OR: [{ featured: true }, { popular: true }] },
        take: 8,
        orderBy: [{ rating: "desc" }, { reviewCount: "desc" }],
        include: serviceInclude(cityId)
      })
    ]);

    return {
      featuredServices,
      popularServices,
      trendingServices,
      recommendedServices
    };
  });
}

async function getHomeCatalog(cityId?: string, userId?: string) {
  const sections = await getHomeCatalogSections(cityId);
  const recentBookings = userId
    ? await prisma.booking.findMany({
        where: { customerId: userId },
        take: 6,
        orderBy: [{ createdAt: "desc" }],
        include: {
          services: {
            include: {
              service: {
                include: serviceInclude(cityId)
              },
              serviceSubcategory: true
            }
          }
        }
      })
    : [];

  return {
    ...sections,
    recentBookings
  };
}

async function createCategory(data: {
  name: string;
  slug?: string;
  description?: string;
  iconUrl?: string;
  seoTitle?: string;
  seoDescription?: string;
  sortOrder?: number;
  isActive?: boolean;
  featured?: boolean;
  popular?: boolean;
  translations?: Array<Record<string, unknown>>;
}) {
  const rawSlug = data.slug ?? slugify(data.name);
  const slug = await ensureUniqueSlug((candidate) => prisma.serviceCategory.findUnique({ where: { slug: candidate } }), rawSlug);
  const created = await prisma.serviceCategory.create({
    data: {
      name: data.name,
      slug,
      description: data.description,
      iconUrl: data.iconUrl,
      seoTitle: data.seoTitle,
      seoDescription: data.seoDescription,
      sortOrder: data.sortOrder ?? 0,
      isActive: data.isActive ?? true,
      featured: data.featured ?? false,
      popular: data.popular ?? false,
      translations: data.translations
        ? {
            create: data.translations.map((translation) => ({
              locale: String(translation.locale ?? "en"),
              name: String(translation.name ?? data.name),
              description: translation.description ? String(translation.description) : undefined,
              shortDescription: translation.shortDescription ? String(translation.shortDescription) : undefined,
              seoTitle: translation.seoTitle ? String(translation.seoTitle) : undefined,
              seoDescription: translation.seoDescription ? String(translation.seoDescription) : undefined
            }))
          }
        : undefined
    },
    include: catalogInclude()
  });

  await invalidateCatalogCache();
  return created;
}

async function updateCategory(id: string, data: Record<string, unknown>) {
  const existing = await prisma.serviceCategory.findUnique({ where: { id } });
  if (!existing) {
    throw new Error("Category not found");
  }

  const nextSlug = typeof data.slug === "string" ? await ensureUniqueSlug((candidate) => prisma.serviceCategory.findFirst({ where: { slug: candidate, NOT: { id } } }), data.slug) : existing.slug;

  const updated = await prisma.serviceCategory.update({
    where: { id },
    data: {
      name: typeof data.name === "string" ? data.name : undefined,
      slug: nextSlug,
      description: typeof data.description === "string" ? data.description : undefined,
      iconUrl: typeof data.iconUrl === "string" ? data.iconUrl : undefined,
      seoTitle: typeof data.seoTitle === "string" ? data.seoTitle : undefined,
      seoDescription: typeof data.seoDescription === "string" ? data.seoDescription : undefined,
      sortOrder: typeof data.sortOrder === "number" ? data.sortOrder : undefined,
      isActive: typeof data.isActive === "boolean" ? data.isActive : undefined,
      featured: typeof data.featured === "boolean" ? data.featured : undefined,
      popular: typeof data.popular === "boolean" ? data.popular : undefined
    }
  });

  await invalidateCatalogCache();
  return prisma.serviceCategory.findUnique({
    where: { id },
    include: catalogInclude()
  });
}

async function reorderCategories(ids: string[]) {
  await prisma.$transaction(
    ids.map((categoryId, index) =>
      prisma.serviceCategory.update({
        where: { id: categoryId },
        data: { sortOrder: index }
      })
    )
  );

  return prisma.serviceCategory.findMany({
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: catalogInclude()
  });
}

async function reorderSubcategories(categoryId: string, ids: string[]) {
  await prisma.$transaction(
    ids.map((subcategoryId, index) =>
      prisma.serviceSubcategory.updateMany({
        where: { id: subcategoryId, categoryId },
        data: { sortOrder: index }
      })
    )
  );

  return prisma.serviceSubcategory.findMany({
    where: { categoryId },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: {
      translations: true,
      category: true,
      catalogServices: true
    }
  });
}

async function createSubcategory(data: {
  categoryId: string;
  name: string;
  slug?: string;
  description?: string;
  iconUrl?: string;
  seoTitle?: string;
  seoDescription?: string;
  basePrice?: number;
  sortOrder?: number;
  rating?: number;
  reviewCount?: number;
  isActive?: boolean;
  translations?: Array<Record<string, unknown>>;
}) {
  const rawSlug = data.slug ?? slugify(data.name);
  const slug = await ensureUniqueSlug((candidate) => prisma.serviceSubcategory.findUnique({ where: { slug: candidate } }), rawSlug);
  const created = await prisma.serviceSubcategory.create({
    data: {
      categoryId: data.categoryId,
      name: data.name,
      slug,
      description: data.description,
      iconUrl: data.iconUrl,
      seoTitle: data.seoTitle,
      seoDescription: data.seoDescription,
      basePrice: new Prisma.Decimal(data.basePrice ?? 0),
      sortOrder: data.sortOrder ?? 0,
      rating: new Prisma.Decimal(data.rating ?? 0),
      reviewCount: data.reviewCount ?? 0,
      isActive: data.isActive ?? true,
      translations: data.translations
        ? {
            create: data.translations.map((translation) => ({
              locale: String(translation.locale ?? "en"),
              name: String(translation.name ?? data.name),
              description: translation.description ? String(translation.description) : undefined,
              seoTitle: translation.seoTitle ? String(translation.seoTitle) : undefined,
              seoDescription: translation.seoDescription ? String(translation.seoDescription) : undefined
            }))
          }
        : undefined
    },
    include: {
      translations: true,
      category: true,
      catalogServices: true
    }
  });

  await invalidateCatalogCache();
  return created;
}

async function updateSubcategory(id: string, data: Record<string, unknown>) {
  const existing = await prisma.serviceSubcategory.findUnique({ where: { id } });
  if (!existing) {
    throw new Error("Subcategory not found");
  }

  const nextSlug = typeof data.slug === "string" ? await ensureUniqueSlug((candidate) => prisma.serviceSubcategory.findFirst({ where: { slug: candidate, NOT: { id } } }), data.slug) : existing.slug;

  await prisma.serviceSubcategory.update({
    where: { id },
    data: {
      categoryId: typeof data.categoryId === "string" ? data.categoryId : undefined,
      name: typeof data.name === "string" ? data.name : undefined,
      slug: nextSlug,
      description: typeof data.description === "string" ? data.description : undefined,
      iconUrl: typeof data.iconUrl === "string" ? data.iconUrl : undefined,
      seoTitle: typeof data.seoTitle === "string" ? data.seoTitle : undefined,
      seoDescription: typeof data.seoDescription === "string" ? data.seoDescription : undefined,
      basePrice: typeof data.basePrice === "number" ? new Prisma.Decimal(data.basePrice) : undefined,
      sortOrder: typeof data.sortOrder === "number" ? data.sortOrder : undefined,
      rating: typeof data.rating === "number" ? new Prisma.Decimal(data.rating) : undefined,
      reviewCount: typeof data.reviewCount === "number" ? data.reviewCount : undefined,
      isActive: typeof data.isActive === "boolean" ? data.isActive : undefined
    }
  });

  await invalidateCatalogCache();

  return prisma.serviceSubcategory.findUnique({
    where: { id },
    include: {
      translations: true,
      category: true,
      catalogServices: true
    }
  });
}

async function reorderServices(subcategoryId: string, ids: string[]) {
  await prisma.$transaction(
    ids.map((serviceId, index) =>
      prisma.service.updateMany({
        where: { id: serviceId, subcategoryId },
        data: { sortOrder: index }
      })
    )
  );

  return prisma.service.findMany({
    where: { subcategoryId },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: serviceInclude()
  });
}

async function createService(data: {
  categoryId: string;
  subcategoryId: string;
  name: string;
  slug?: string;
  code?: string;
  description?: string;
  shortDescription?: string;
  startingPrice: number;
  gstRate?: number;
  sacCode?: string;
  estimatedDurationMins: number;
  warrantyDays?: number;
  gstApplicable?: boolean;
  emergencyAvailable?: boolean;
  homeVisit?: boolean;
  isActive?: boolean;
  featured?: boolean;
  popular?: boolean;
  rating?: number;
  reviewCount?: number;
  cancellationPolicy?: string;
  seoTitle?: string;
  seoDescription?: string;
  seoKeywords?: string;
  iconUrl?: string;
  sortOrder?: number;
  translations?: Array<Record<string, unknown>>;
  images?: Array<Record<string, unknown>>;
  requiredSkills?: Array<Record<string, unknown>>;
  requiredTools?: Array<Record<string, unknown>>;
  requiredDocuments?: Array<Record<string, unknown>>;
}) {
  const rawSlug = data.slug ?? slugify(data.name);
  const slug = await ensureUniqueSlug((candidate) => prisma.service.findUnique({ where: { slug: candidate } }), rawSlug);
  const code = data.code ?? uniqueCode("SRV", data.name);

  const created = await prisma.service.create({
    data: {
      categoryId: data.categoryId,
      subcategoryId: data.subcategoryId,
      name: data.name,
      slug,
      code,
      description: data.description,
      shortDescription: data.shortDescription,
      startingPrice: new Prisma.Decimal(data.startingPrice),
      gstRate: new Prisma.Decimal(data.gstRate ?? 18),
      sacCode: normalizeSacCode(data.sacCode),
      estimatedDurationMins: data.estimatedDurationMins,
      warrantyDays: data.warrantyDays ?? 0,
      gstApplicable: data.gstApplicable ?? true,
      emergencyAvailable: data.emergencyAvailable ?? false,
      homeVisit: data.homeVisit ?? true,
      isActive: data.isActive ?? true,
      featured: data.featured ?? false,
      popular: data.popular ?? false,
      rating: new Prisma.Decimal(data.rating ?? 0),
      reviewCount: data.reviewCount ?? 0,
      cancellationPolicy: data.cancellationPolicy,
      seoTitle: data.seoTitle,
      seoDescription: data.seoDescription,
      seoKeywords: data.seoKeywords,
      iconUrl: data.iconUrl,
      sortOrder: data.sortOrder ?? 0,
      translations: data.translations
        ? {
            create: data.translations.map((translation) => ({
              locale: String(translation.locale ?? "en"),
              name: String(translation.name ?? data.name),
              shortDescription: translation.shortDescription ? String(translation.shortDescription) : undefined,
              description: translation.description ? String(translation.description) : undefined,
              seoTitle: translation.seoTitle ? String(translation.seoTitle) : undefined,
              seoDescription: translation.seoDescription ? String(translation.seoDescription) : undefined
            }))
          }
        : undefined,
      images: data.images
        ? {
            create: data.images.map((image, index) => ({
              url: String(image.url),
              altText: image.altText ? String(image.altText) : undefined,
              sortOrder: typeof image.sortOrder === "number" ? image.sortOrder : index,
              isPrimary: typeof image.isPrimary === "boolean" ? image.isPrimary : index === 0
            }))
          }
        : undefined,
      requiredSkills: data.requiredSkills
        ? {
            create: await Promise.all(
              data.requiredSkills.map(async (item, index) => ({
                skillId: await resolveSkillId(String(item.name), String(item.slug)),
                isMandatory: typeof item.isMandatory === "boolean" ? item.isMandatory : true,
                sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
              }))
            )
          }
        : undefined,
      requiredTools: data.requiredTools
        ? {
            create: await Promise.all(
              data.requiredTools.map(async (item, index) => ({
                toolId: await resolveToolId(String(item.name), String(item.slug)),
                isMandatory: typeof item.isMandatory === "boolean" ? item.isMandatory : true,
                sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
              }))
            )
          }
        : undefined,
      requiredDocuments: data.requiredDocuments
        ? {
            create: data.requiredDocuments.map((item, index) => ({
              name: String(item.name),
              slug: String(item.slug),
              isMandatory: typeof item.isMandatory === "boolean" ? item.isMandatory : true,
              sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
            }))
          }
        : undefined,
      
    },
    include: serviceInclude()
  });

  await invalidateCatalogCache();
  return created;
}

async function updateService(id: string, data: Record<string, unknown>) {
  const existing = await prisma.service.findUnique({ where: { id } });
  if (!existing) {
    throw new Error("Service not found");
  }

  const nextSlug = typeof data.slug === "string" ? await ensureUniqueSlug((candidate) => prisma.service.findFirst({ where: { slug: candidate, NOT: { id } } }), data.slug) : existing.slug;
  const nextCode = typeof data.code === "string" ? data.code : existing.code;

  await prisma.service.update({
    where: { id },
    data: {
      categoryId: typeof data.categoryId === "string" ? data.categoryId : undefined,
      subcategoryId: typeof data.subcategoryId === "string" ? data.subcategoryId : undefined,
      name: typeof data.name === "string" ? data.name : undefined,
      slug: nextSlug,
      code: nextCode,
      description: typeof data.description === "string" ? data.description : undefined,
      shortDescription: typeof data.shortDescription === "string" ? data.shortDescription : undefined,
      startingPrice: typeof data.startingPrice === "number" ? new Prisma.Decimal(data.startingPrice) : undefined,
      gstRate: typeof data.gstRate === "number" ? new Prisma.Decimal(data.gstRate) : undefined,
      sacCode: typeof data.sacCode === "string" ? normalizeSacCode(data.sacCode) : undefined,
      estimatedDurationMins: typeof data.estimatedDurationMins === "number" ? data.estimatedDurationMins : undefined,
      warrantyDays: typeof data.warrantyDays === "number" ? data.warrantyDays : undefined,
      gstApplicable: typeof data.gstApplicable === "boolean" ? data.gstApplicable : undefined,
      emergencyAvailable: typeof data.emergencyAvailable === "boolean" ? data.emergencyAvailable : undefined,
      homeVisit: typeof data.homeVisit === "boolean" ? data.homeVisit : undefined,
      isActive: typeof data.isActive === "boolean" ? data.isActive : undefined,
      featured: typeof data.featured === "boolean" ? data.featured : undefined,
      popular: typeof data.popular === "boolean" ? data.popular : undefined,
      rating: typeof data.rating === "number" ? new Prisma.Decimal(data.rating) : undefined,
      reviewCount: typeof data.reviewCount === "number" ? data.reviewCount : undefined,
      cancellationPolicy: typeof data.cancellationPolicy === "string" ? data.cancellationPolicy : undefined,
      seoTitle: typeof data.seoTitle === "string" ? data.seoTitle : undefined,
      seoDescription: typeof data.seoDescription === "string" ? data.seoDescription : undefined,
      seoKeywords: typeof data.seoKeywords === "string" ? data.seoKeywords : undefined,
      iconUrl: typeof data.iconUrl === "string" ? data.iconUrl : undefined,
      sortOrder: typeof data.sortOrder === "number" ? data.sortOrder : undefined
    }
  });

  if (Array.isArray(data.images)) {
    await prisma.serviceImage.deleteMany({ where: { serviceId: id } });
    await prisma.serviceImage.createMany({
      data: data.images.map((image, index) => ({
        serviceId: id,
        url: String(image.url),
        altText: image.altText ? String(image.altText) : undefined,
        sortOrder: typeof image.sortOrder === "number" ? image.sortOrder : index,
        isPrimary: typeof image.isPrimary === "boolean" ? image.isPrimary : index === 0
      }))
    });
  }

  if (Array.isArray(data.requiredSkills)) {
    await prisma.serviceRequiredSkill.deleteMany({ where: { serviceId: id } });
    const skillRows = await Promise.all(
      data.requiredSkills.map(async (item, index) => ({
        serviceId: id,
        skillId: await resolveSkillId(String(item.name), String(item.slug)),
        isMandatory: typeof item.isMandatory === "boolean" ? item.isMandatory : true,
        sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
      }))
    );
    await prisma.serviceRequiredSkill.createMany({ data: skillRows });
  }

  if (Array.isArray(data.requiredTools)) {
    await prisma.serviceRequiredTool.deleteMany({ where: { serviceId: id } });
    const toolRows = await Promise.all(
      data.requiredTools.map(async (item, index) => ({
        serviceId: id,
        toolId: await resolveToolId(String(item.name), String(item.slug)),
        isMandatory: typeof item.isMandatory === "boolean" ? item.isMandatory : true,
        sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
      }))
    );
    await prisma.serviceRequiredTool.createMany({ data: toolRows });
  }

  if (Array.isArray(data.requiredDocuments)) {
    await prisma.serviceRequiredDocument.deleteMany({ where: { serviceId: id } });
    await prisma.serviceRequiredDocument.createMany({
      data: data.requiredDocuments.map((item, index) => ({
        serviceId: id,
        name: String(item.name),
        slug: String(item.slug),
        isMandatory: typeof item.isMandatory === "boolean" ? item.isMandatory : true,
        sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
      }))
    });
  }

  if (Array.isArray(data.translations)) {
    await prisma.serviceTranslation.deleteMany({ where: { serviceId: id } });
    await prisma.serviceTranslation.createMany({
      data: data.translations.map((translation) => ({
        serviceId: id,
        locale: String(translation.locale ?? "en"),
        name: String(translation.name ?? existing.name),
        shortDescription: translation.shortDescription ? String(translation.shortDescription) : undefined,
        description: translation.description ? String(translation.description) : undefined,
        seoTitle: translation.seoTitle ? String(translation.seoTitle) : undefined,
        seoDescription: translation.seoDescription ? String(translation.seoDescription) : undefined
      }))
    });
  }

  await invalidateCatalogCache();

  return prisma.service.findUnique({
    where: { id },
    include: serviceInclude()
  });
}

async function addServiceImages(id: string, images: Array<{ url: string; altText?: string; sortOrder?: number; isPrimary?: boolean }>) {
  const count = await prisma.serviceImage.count({ where: { serviceId: id } });
  await prisma.serviceImage.createMany({
    data: images.map((image, index) => ({
      serviceId: id,
      url: image.url,
      altText: image.altText,
      sortOrder: image.sortOrder ?? count + index,
      isPrimary: image.isPrimary ?? false
    }))
  });
  await invalidateCatalogCache();
  return prisma.service.findUnique({ where: { id }, include: serviceInclude() });
}

async function upsertPriceRule(serviceId: string, data: {
  cityId?: string;
  type: string;
  title: string;
  description?: string;
  currency?: string;
  price: number;
  startsAt?: string;
  endsAt?: string;
  isActive?: boolean;
  priority?: number;
}) {
  const created = await prisma.servicePriceRule.create({
    data: {
      serviceId,
      cityId: data.cityId,
      type: data.type as PriceRuleType,
      title: data.title,
      description: data.description,
      currency: data.currency ?? "INR",
      price: new Prisma.Decimal(data.price),
      startsAt: data.startsAt ? new Date(data.startsAt) : undefined,
      endsAt: data.endsAt ? new Date(data.endsAt) : undefined,
      isActive: data.isActive ?? true,
      priority: data.priority ?? 0
    }
  });

  await invalidateCatalogCache();
  return created;
}

async function updatePriceRule(id: string, data: Record<string, unknown>) {
  const updated = await prisma.servicePriceRule.update({
    where: { id },
    data: {
      cityId: typeof data.cityId === "string" ? data.cityId : undefined,
      type: typeof data.type === "string" ? (data.type as PriceRuleType) : undefined,
      title: typeof data.title === "string" ? data.title : undefined,
      description: typeof data.description === "string" ? data.description : undefined,
      currency: typeof data.currency === "string" ? data.currency : undefined,
      price: typeof data.price === "number" ? new Prisma.Decimal(data.price) : undefined,
      startsAt: typeof data.startsAt === "string" ? new Date(data.startsAt) : undefined,
      endsAt: typeof data.endsAt === "string" ? new Date(data.endsAt) : undefined,
      isActive: typeof data.isActive === "boolean" ? data.isActive : undefined,
      priority: typeof data.priority === "number" ? data.priority : undefined
    }
  });

  await invalidateCatalogCache();
  return updated;
}

async function importCatalog(categories: Array<Record<string, unknown>>) {
  let categoryCount = 0;
  let subcategoryCount = 0;
  let serviceCount = 0;

  for (const category of categories) {
    const createdCategory = await createOrUpdateCategoryFromImport(category);
    categoryCount += 1;

    const subcategories = Array.isArray(category.subcategories) ? category.subcategories as Array<Record<string, unknown>> : [];
    for (const subcategory of subcategories) {
      const createdSubcategory = await createOrUpdateSubcategoryFromImport(createdCategory.id, subcategory);
      subcategoryCount += 1;

      const services = Array.isArray(subcategory.services) ? subcategory.services as Array<Record<string, unknown>> : [];
      for (const service of services) {
        await createOrUpdateServiceFromImport(createdCategory.id, createdSubcategory.id, service);
        serviceCount += 1;
      }
    }
  }

  await invalidateCatalogCache();
  return { categoryCount, subcategoryCount, serviceCount };
}

async function createOrUpdateCategoryFromImport(category: Record<string, unknown>) {
  const slug = String(category.slug ?? slugify(String(category.name ?? "category")));
  const existing = await prisma.serviceCategory.findUnique({ where: { slug } });
  const payload = {
    name: String(category.name ?? slug),
    slug,
    description: category.description ? String(category.description) : undefined,
    iconUrl: category.iconUrl ? String(category.iconUrl) : undefined,
    seoTitle: category.seoTitle ? String(category.seoTitle) : undefined,
    seoDescription: category.seoDescription ? String(category.seoDescription) : undefined,
    sortOrder: typeof category.sortOrder === "number" ? category.sortOrder : 0,
    isActive: typeof category.isActive === "boolean" ? category.isActive : true,
    featured: typeof category.featured === "boolean" ? category.featured : false,
    popular: typeof category.popular === "boolean" ? category.popular : false
  };

  if (!existing) {
    return prisma.serviceCategory.create({ data: payload });
  }

  return prisma.serviceCategory.update({
    where: { id: existing.id },
    data: payload
  });
}

async function createOrUpdateSubcategoryFromImport(categoryId: string, subcategory: Record<string, unknown>) {
  const slug = String(subcategory.slug ?? slugify(String(subcategory.name ?? "subcategory")));
  const existing = await prisma.serviceSubcategory.findUnique({ where: { slug } });
  const payload = {
    categoryId,
    name: String(subcategory.name ?? slug),
    slug,
    description: subcategory.description ? String(subcategory.description) : undefined,
    iconUrl: subcategory.iconUrl ? String(subcategory.iconUrl) : undefined,
    basePrice: new Prisma.Decimal(typeof subcategory.basePrice === "number" ? subcategory.basePrice : 0),
    sortOrder: typeof subcategory.sortOrder === "number" ? subcategory.sortOrder : 0,
    isActive: typeof subcategory.isActive === "boolean" ? subcategory.isActive : true
  };

  if (!existing) {
    return prisma.serviceSubcategory.create({ data: payload });
  }

  return prisma.serviceSubcategory.update({
    where: { id: existing.id },
    data: payload
  });
}

async function createOrUpdateServiceFromImport(categoryId: string, subcategoryId: string, service: Record<string, unknown>) {
  const slug = String(service.slug ?? slugify(String(service.name ?? "service")));
  const existing = await prisma.service.findUnique({ where: { slug } });
  const payload = {
    categoryId,
    subcategoryId,
    name: String(service.name ?? slug),
    slug,
    code: String(service.code ?? uniqueCode("SRV", String(service.name ?? slug))),
    description: service.description ? String(service.description) : undefined,
    shortDescription: service.shortDescription ? String(service.shortDescription) : undefined,
    startingPrice: new Prisma.Decimal(typeof service.startingPrice === "number" ? service.startingPrice : 0),
    gstRate: new Prisma.Decimal(typeof service.gstRate === "number" ? service.gstRate : 18),
    sacCode: normalizeSacCode(typeof service.sacCode === "string" ? service.sacCode : undefined),
    estimatedDurationMins: typeof service.estimatedDurationMins === "number" ? service.estimatedDurationMins : 30,
    warrantyDays: typeof service.warrantyDays === "number" ? service.warrantyDays : 0,
    gstApplicable: typeof service.gstApplicable === "boolean" ? service.gstApplicable : true,
    emergencyAvailable: typeof service.emergencyAvailable === "boolean" ? service.emergencyAvailable : false,
    homeVisit: typeof service.homeVisit === "boolean" ? service.homeVisit : true,
    isActive: typeof service.isActive === "boolean" ? service.isActive : true,
    featured: typeof service.featured === "boolean" ? service.featured : false,
    popular: typeof service.popular === "boolean" ? service.popular : false,
    rating: new Prisma.Decimal(typeof service.rating === "number" ? service.rating : 0),
    reviewCount: typeof service.reviewCount === "number" ? service.reviewCount : 0,
    iconUrl: service.iconUrl ? String(service.iconUrl) : undefined,
    sortOrder: typeof service.sortOrder === "number" ? service.sortOrder : 0
  };

  if (!existing) {
    return prisma.service.create({ data: payload });
  }

  return prisma.service.update({
    where: { id: existing.id },
    data: payload
  });
}

export const catalogService = {
  resolveCatalogTree,
  resolveCategoryBySlug,
  resolveSubcategoryBySlug,
  resolveServiceBySlug,
  searchCatalog,
  getAutocompleteSuggestions,
  getHomeCatalog,
  createCategory,
  updateCategory,
  reorderCategories,
  reorderSubcategories,
  createSubcategory,
  updateSubcategory,
  reorderServices,
  createService,
  updateService,
  addServiceImages,
  upsertPriceRule,
  updatePriceRule,
  importCatalog
};
