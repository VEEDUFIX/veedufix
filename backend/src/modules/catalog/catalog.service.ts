import { Prisma, PriceRuleType } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { AppError } from "../../lib/app-error.js";
import { redis } from "../../lib/redis.js";
import { serviceAvailabilityWhere, variantAvailabilityWhere } from "./availability-inheritance.js";
import { expandSearchQuery, searchRelevanceScore } from "./search-vocabulary.js";

type LocaleInput = {
  locale?: string;
  cityId?: string;
  pincode?: string;
};

type PublicCatalogFilter = LocaleInput & {
  q?: string;
  categorySlug?: string;
  subcategorySlug?: string;
  page?: number;
  pageSize?: number;
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

// Keep publication-window transitions visible promptly. A short TTL also
// covers upcoming start times that are absent from the currently eligible
// query result and therefore cannot contribute an exact expiry boundary.
const CATALOG_CACHE_TTL_SECONDS = 15;
const CATALOG_CACHE_VERSION_KEY = "cache:catalog:version";
const MAX_MATERIALIZED_REMOVE_AREAS = 1000;
const MAX_RANKED_SEARCH_RESULTS = 240;

export function publicServiceEligibility(
  at = new Date(),
  serviceAreaIds?: string[] | null
): Prisma.ServiceWhereInput {
  if (serviceAreaIds === null || (serviceAreaIds && serviceAreaIds.length === 0)) {
    return { id: "__no_serviceable_area__" };
  }
  const availability: Prisma.ServiceWhereInput[] = [
    { OR: [{ publishStartsAt: null }, { publishStartsAt: { lte: at } }] },
    { OR: [{ publishEndsAt: null }, { publishEndsAt: { gte: at } }] }
  ];
  if (serviceAreaIds?.length) {
    availability.push(serviceAvailabilityWhere(serviceAreaIds));
  }
  return {
    isActive: true,
    publicationStatus: "PUBLISHED",
    AND: availability
  };
}

async function resolveServiceAreaIds(pincode?: string): Promise<string[] | null | undefined> {
  if (pincode === undefined) return undefined;
  const matchingAreas = await prisma.serviceArea.findMany({
    where: {
      isActive: true,
      city: { isActive: true },
      OR: [
        { pincode },
        { assignedPincodes: { some: { pincode } } },
        { pincodeRangeStart: { lte: pincode }, pincodeRangeEnd: { gte: pincode } }
      ]
    },
    select: { id: true }
  });
  return matchingAreas.length > 0 ? matchingAreas.map((area) => area.id) : null;
}

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

export async function invalidatePublicCatalogCache(): Promise<void> {
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

const invalidateCatalogCache = invalidatePublicCatalogCache;

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

async function resolveSkillId(
  name: string,
  slug?: string,
  client: Prisma.TransactionClient = prisma
) {
  const skillSlug = slug ? slugify(slug) : slugify(name);
  const existing = await client.skill.findUnique({ where: { slug: skillSlug } });
  if (existing) {
    return existing.id;
  }

  const skill = await client.skill.create({
    data: {
      name,
      slug: skillSlug
    }
  });

  return skill.id;
}

async function resolveToolId(
  name: string,
  slug?: string,
  client: Prisma.TransactionClient = prisma
) {
  const toolSlug = slug ? slugify(slug) : slugify(name);
  const existing = await client.tool.findUnique({ where: { slug: toolSlug } });
  if (existing) {
    return existing.id;
  }

  const tool = await client.tool.create({
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

function catalogInclude(cityId?: string, serviceAreaId?: string[] | null) {
  return {
    translations: true,
    subcategories: {
      where: {
        isActive: true,
        catalogServices: {
          some: { ...publicServiceEligibility(new Date(), serviceAreaId) }
        }
      },
      orderBy: [{ sortOrder: "asc" as const }, { name: "asc" as const }],
      include: {
        translations: true,
        _count: {
          select: {
            catalogServices: { where: publicServiceEligibility(new Date(), serviceAreaId) }
          }
        }
      }
    },
    _count: {
      select: {
        services: { where: publicServiceEligibility(new Date(), serviceAreaId) },
        subcategories: {
          where: {
            isActive: true,
            catalogServices: { some: publicServiceEligibility(new Date(), serviceAreaId) }
          }
        }
      }
    }
  } satisfies Prisma.ServiceCategoryInclude;
}

function adminCatalogInclude() {
  return {
    translations: true,
    subcategories: {
      orderBy: [{ sortOrder: "asc" as const }, { name: "asc" as const }],
      include: {
        translations: true,
        _count: { select: { catalogServices: true } }
      }
    },
    _count: { select: { services: true, subcategories: true } }
  } satisfies Prisma.ServiceCategoryInclude;
}

function serviceInclude(cityId?: string, serviceAreaIds?: string[] | null) {
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
    variants: {
      where: {
        isAvailable: true,
        ...(serviceAreaIds?.length ? variantAvailabilityWhere(serviceAreaIds) : {})
      },
      orderBy: [{ sortOrder: "asc" as const }, { createdAt: "asc" as const }]
    },
    addons: {
      where: { isActive: true },
      orderBy: [{ sortOrder: "asc" as const }, { createdAt: "asc" as const }]
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

async function resolveCatalogTree(cityId?: string, locale?: string, pincode?: string) {
  const serviceAreaId = await resolveServiceAreaIds(pincode);
  const where = {
    isActive: true,
    subcategories: {
      some: {
        isActive: true,
        catalogServices: {
          some: { ...publicServiceEligibility(new Date(), serviceAreaId) }
        }
      }
    }
  };
  return readCatalogCache("tree", [cityId, locale, pincode, "active"], async () =>
    prisma.serviceCategory.findMany({
      where,
      orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
      include: {
        ...catalogInclude(cityId, serviceAreaId)
      }
    })
  );
}

type AdminCatalogFilters = {
  stateId?: string;
  districtId?: string;
  cityId?: string;
  areaId?: string;
  pincode?: string;
  categoryId?: string;
  subcategoryId?: string;
  serviceId?: string;
  availabilityStatus?: "INHERITED" | "CUSTOM" | "AVAILABLE" | "UNAVAILABLE";
  isActive?: boolean;
};

async function resolveAdminCatalogTree(filters: AdminCatalogFilters = {}) {
  const hasLocationFilter = Boolean(
    filters.stateId || filters.districtId || filters.cityId || filters.areaId || filters.pincode
  );
  const matchingAreas = hasLocationFilter
    ? await prisma.serviceArea.findMany({
      where: {
          isActive: true,
          ...(filters.areaId ? { id: filters.areaId } : {}),
          ...(filters.cityId ? { cityId: filters.cityId } : {}),
          city: {
            isActive: true,
            ...(filters.stateId ? { stateId: filters.stateId } : {}),
            ...(filters.districtId ? { districtId: filters.districtId } : {})
          },
          ...(filters.pincode
            ? {
                OR: [
                  { pincode: filters.pincode },
                  { assignedPincodes: { some: { pincode: filters.pincode } } },
                  {
                    pincodeRangeStart: { lte: filters.pincode },
                    pincodeRangeEnd: { gte: filters.pincode }
                  }
                ]
              }
            : {})
        },
        select: { id: true }
      })
    : [];
  const serviceAreaIds = matchingAreas.map((area) => area.id);
  let locationAvailability: Prisma.ServiceWhereInput | undefined;
  if (hasLocationFilter) {
    if (filters.availabilityStatus === "UNAVAILABLE") {
      locationAvailability = serviceAreaIds.length
        ? { NOT: serviceAvailabilityWhere(serviceAreaIds) }
        : {};
    } else {
      locationAvailability = serviceAreaIds.length
        ? serviceAvailabilityWhere(serviceAreaIds)
        : { id: "__no_matching_service_area__" };
    }
  }
  const modeFilter = filters.availabilityStatus === "INHERITED" || filters.availabilityStatus === "CUSTOM"
    ? { availabilityMode: filters.availabilityStatus }
    : {};
  const serviceWhere: Prisma.ServiceWhereInput = {
    ...(filters.serviceId ? { id: filters.serviceId } : {}),
    ...(filters.isActive !== undefined ? { isActive: filters.isActive } : {}),
    ...modeFilter,
    ...(locationAvailability ?? {})
  };
  const subcategoryWhere = {
    ...(filters.subcategoryId ? { id: filters.subcategoryId } : {}),
    catalogServices: { some: serviceWhere }
  };
  const categoryWhere = {
    ...(filters.categoryId ? { id: filters.categoryId } : {}),
    ...(filters.subcategoryId || filters.serviceId || hasLocationFilter || filters.availabilityStatus || filters.isActive !== undefined
      ? { subcategories: { some: subcategoryWhere } }
      : {})
  };
  return prisma.serviceCategory.findMany({
    where: categoryWhere,
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: {
      translations: true,
      serviceAreaAssignments: {
        include: { serviceArea: { select: { id: true, name: true, isActive: true, cityId: true } } },
        orderBy: [{ serviceAreaId: "asc" }]
      },
      subcategories: {
        where: filters.subcategoryId || filters.serviceId || hasLocationFilter || filters.availabilityStatus || filters.isActive !== undefined
          ? subcategoryWhere
          : undefined,
        orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
        include: {
          translations: true,
          serviceAreaAssignments: {
            include: { serviceArea: { select: { id: true, name: true, isActive: true, cityId: true } } },
            orderBy: [{ serviceAreaId: "asc" }]
          },
          catalogServices: {
            where: filters.serviceId || hasLocationFilter || filters.availabilityStatus || filters.isActive !== undefined
              ? serviceWhere
              : undefined,
            orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
            include: {
              translations: true,
              images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
              pricingRules: { orderBy: [{ priority: "desc" }, { createdAt: "desc" }] },
              requiredSkills: { include: { skill: true }, orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
              requiredTools: { include: { tool: true }, orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
              requiredDocuments: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
              variants: {
                orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
                include: {
                  serviceAreaAssignments: {
                    include: { serviceArea: { select: { id: true, name: true, isActive: true, cityId: true } } },
                    orderBy: [{ serviceAreaId: "asc" }]
                  }
                }
              },
              addons: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
              serviceAreaAssignments: {
                include: { serviceArea: { select: { id: true, name: true, isActive: true, cityId: true } } },
                orderBy: [{ serviceAreaId: "asc" }]
              }
            }
          }
        }
      }
    }
  });
}

async function resolveServiceBySlug(slug: string, cityId?: string, pincode?: string) {
  const serviceAreaId = await resolveServiceAreaIds(pincode);
  return readCatalogCache("service", [slug, cityId, pincode], async () =>
    prisma.service.findFirst({
      where: {
        ...publicServiceEligibility(new Date(), serviceAreaId),
        OR: [{ slug }, { id: slug }]
      },
      include: serviceInclude(cityId, serviceAreaId)
    })
  );
}

async function resolveCategoryBySlug(slug: string, pincode?: string) {
  const serviceAreaId = await resolveServiceAreaIds(pincode);
  return readCatalogCache("category", [slug, pincode], async () =>
    prisma.serviceCategory.findFirst({
      where: {
        slug,
        isActive: true,
        subcategories: {
          some: {
            isActive: true,
            catalogServices: { some: publicServiceEligibility(new Date(), serviceAreaId) }
          }
        }
      },
      include: {
        translations: true,
        subcategories: {
          where: {
            isActive: true,
            catalogServices: { some: publicServiceEligibility(new Date(), serviceAreaId) }
          },
          orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
          select: {
            id: true,
            categoryId: true,
            name: true,
            slug: true,
            description: true,
            iconUrl: true,
            sortOrder: true,
            isActive: true,
            translations: true,
            _count: {
              select: {
                catalogServices: { where: publicServiceEligibility(new Date(), serviceAreaId) }
              }
            }
          }
        }
      }
    })
  );
}

async function resolveSubcategoryBySlug(slug: string, pincode?: string) {
  const serviceAreaId = await resolveServiceAreaIds(pincode);
  return readCatalogCache("subcategory", [slug, pincode], async () =>
    prisma.serviceSubcategory.findFirst({
      where: {
        slug,
        isActive: true,
        category: { isActive: true },
        catalogServices: { some: publicServiceEligibility(new Date(), serviceAreaId) }
      },
      include: {
        translations: true,
        category: { include: { translations: true } },
        catalogServices: {
          where: publicServiceEligibility(new Date(), serviceAreaId),
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
  const serviceAreaId = await resolveServiceAreaIds(input.pincode);
  const searchTerms = input.q ? expandSearchQuery(input.q) : [];
  const where: Prisma.ServiceWhereInput = {
    ...publicServiceEligibility(new Date(), serviceAreaId),
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
      ? searchTerms.flatMap((term): Prisma.ServiceWhereInput[] => [
          { name: { contains: term, mode: "insensitive" } },
          { slug: { contains: term, mode: "insensitive" } },
          { code: { contains: term, mode: "insensitive" } },
          { description: { contains: term, mode: "insensitive" } },
          { shortDescription: { contains: term, mode: "insensitive" } },
          { seoKeywords: { contains: term, mode: "insensitive" } },
          {
            category: {
              OR: [
                { name: { contains: term, mode: "insensitive" } },
                { slug: { contains: term, mode: "insensitive" } }
              ]
            }
          },
          {
            subcategory: {
              OR: [
                { name: { contains: term, mode: "insensitive" } },
                { slug: { contains: term, mode: "insensitive" } }
              ]
            }
          },
          { searchKeywords: { some: { keyword: { contains: term, mode: "insensitive" } } } }
        ])
      : undefined
  };

  const page = input.page ?? 1;
  const pageSize = input.pageSize ?? 20;
  const [items, total] = await Promise.all([
    input.q
      ? prisma.service.findMany({
          where,
          take: MAX_RANKED_SEARCH_RESULTS * 4,
          orderBy: input.subcategorySlug
            ? [{ sortOrder: "asc" }, { name: "asc" }]
            : [{ featured: "desc" }, { popular: "desc" }, { reviewCount: "desc" }, { sortOrder: "asc" }],
          select: { id: true, name: true, popular: true, featured: true, sortOrder: true }
        })
      : prisma.service.findMany({
          where,
          take: pageSize,
          skip: (page - 1) * pageSize,
          orderBy: input.subcategorySlug
            ? [{ sortOrder: "asc" }, { name: "asc" }]
            : [{ featured: "desc" }, { popular: "desc" }, { reviewCount: "desc" }, { sortOrder: "asc" }],
          include: serviceInclude(input.cityId, serviceAreaId)
        }),
    prisma.service.count({ where })
  ]);

  let rankedItems: unknown[];
  if (input.q) {
    const rankedCandidates = items
      .sort((left, right) => {
        const relevanceFor = (name: string) =>
          Math.max(...searchTerms.map((term) => searchRelevanceScore(name, term)));
        const relevance = relevanceFor(right.name) - relevanceFor(left.name);
        if (relevance !== 0) return relevance;
        if (left.popular !== right.popular) return left.popular ? -1 : 1;
        if (left.featured !== right.featured) return left.featured ? -1 : 1;
        return left.sortOrder - right.sortOrder;
      })
      .slice(0, MAX_RANKED_SEARCH_RESULTS);
    const pageIds = rankedCandidates
      .slice((page - 1) * pageSize, page * pageSize)
      .map((item) => item.id);
    const pageItems = pageIds.length
      ? await prisma.service.findMany({
          where: { ...where, id: { in: pageIds } },
          include: serviceInclude(input.cityId, serviceAreaId)
        })
      : [];
    const itemsById = new Map(pageItems.map((item) => [item.id, item]));
    rankedItems = pageIds.flatMap((id) => {
      const item = itemsById.get(id);
      return item ? [item] : [];
    });
  } else {
    rankedItems = items;
  }

  return {
    items: rankedItems,
    total: input.q ? Math.min(total, MAX_RANKED_SEARCH_RESULTS) : total,
    ...(input.q ? { resultLimit: MAX_RANKED_SEARCH_RESULTS } : {})
  };
}

async function getAutocompleteSuggestions(
  query: string,
  limit: number,
  cityId?: string,
  pincode?: string
) {
  const serviceAreaId = await resolveServiceAreaIds(pincode);
  const searchTerms = expandSearchQuery(query);
  const [services, categories, subcategories] = await readCatalogCache("autocomplete", [query, String(limit), cityId, pincode], async () =>
    Promise.all([
      prisma.service.findMany({
        where: {
          ...publicServiceEligibility(new Date(), serviceAreaId),
          OR: searchTerms.flatMap((term) => [
            { name: { contains: term, mode: "insensitive" as const } },
            { code: { contains: term, mode: "insensitive" as const } },
            { slug: { contains: term, mode: "insensitive" as const } },
            { seoKeywords: { contains: term, mode: "insensitive" as const } },
            { searchKeywords: { some: { keyword: { contains: term, mode: "insensitive" as const } } } }
          ])
        },
        take: 200,
        orderBy: [{ popular: "desc" }, { reviewCount: "desc" }, { sortOrder: "asc" }],
        select: {
          name: true,
          slug: true,
          popular: true,
          reviewCount: true,
          sortOrder: true,
          category: { select: { slug: true } },
          subcategory: { select: { slug: true } }
        }
      }),
      prisma.serviceCategory.findMany({
        where: {
          isActive: true,
          subcategories: {
            some: {
              isActive: true,
              catalogServices: { some: publicServiceEligibility(new Date(), serviceAreaId) }
            }
          },
          OR: searchTerms.flatMap((term) => [
            { name: { contains: term, mode: "insensitive" as const } },
            { slug: { contains: term, mode: "insensitive" as const } }
          ])
        },
        select: { name: true, slug: true }
      }),
      prisma.serviceSubcategory.findMany({
        where: {
          isActive: true,
          category: { isActive: true },
          catalogServices: { some: publicServiceEligibility(new Date(), serviceAreaId) },
          OR: searchTerms.flatMap((term) => [
            { name: { contains: term, mode: "insensitive" as const } },
            { slug: { contains: term, mode: "insensitive" as const } }
          ])
        },
        select: {
          name: true,
          slug: true,
          category: { select: { slug: true } }
        }
      })
    ])
  );

  services.sort((left, right) => {
    const relevanceFor = (name: string) =>
      Math.max(...searchTerms.map((term) => searchRelevanceScore(name, term)));
    const relevance = relevanceFor(right.name) - relevanceFor(left.name);
    if (relevance !== 0) return relevance;
    return Number(right.popular) - Number(left.popular) ||
      right.reviewCount - left.reviewCount ||
      left.sortOrder - right.sortOrder ||
      left.name.localeCompare(right.name);
  });
  const relevanceFor = (name: string) =>
    Math.max(...searchTerms.map((term) => searchRelevanceScore(name, term)));
  categories.sort((left, right) => relevanceFor(right.name) - relevanceFor(left.name) || left.name.localeCompare(right.name));
  subcategories.sort((left, right) => relevanceFor(right.name) - relevanceFor(left.name) || left.name.localeCompare(right.name));

  return {
    services: services.slice(0, Math.min(limit * 3, 50)).map((item) => ({
      label: item.name,
      kind: "SERVICE",
      slug: item.slug,
      categorySlug: item.category.slug,
      subcategorySlug: item.subcategory.slug
    })),
    categories: categories.slice(0, limit).map((item) => ({
      label: item.name,
      kind: "CATEGORY",
      slug: item.slug
    })),
    subcategories: subcategories.slice(0, limit).map((item) => ({
      label: item.name,
      kind: "SUBCATEGORY",
      slug: item.slug,
      categorySlug: item.category.slug
    }))
  };
}

async function getHomeCatalogSections(cityId?: string, pincode?: string) {
  const serviceAreaId = await resolveServiceAreaIds(pincode);
  return readCatalogCache("home-sections", [cityId, pincode], async () => {
    const [categories, featuredServices, popularServices, trendingServices, recommendedServices] = await Promise.all([
      prisma.serviceCategory.findMany({
        where: {
          isActive: true,
          subcategories: {
            some: {
              isActive: true,
              catalogServices: { some: publicServiceEligibility(new Date(), serviceAreaId) }
            }
          }
        },
        take: 7,
        orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
        select: {
          id: true,
          name: true,
          slug: true,
          description: true,
          iconUrl: true,
          sortOrder: true,
          isActive: true,
          featured: true,
          popular: true
        }
      }),
      prisma.service.findMany({
        where: { ...publicServiceEligibility(new Date(), serviceAreaId), featured: true },
        take: 8,
        orderBy: [{ sortOrder: "asc" }, { reviewCount: "desc" }],
        include: serviceInclude(cityId, serviceAreaId)
      }),
      prisma.service.findMany({
        where: { ...publicServiceEligibility(new Date(), serviceAreaId), popular: true },
        take: 8,
        orderBy: [{ reviewCount: "desc" }, { rating: "desc" }],
        include: serviceInclude(cityId, serviceAreaId)
      }),
      prisma.service.findMany({
        where: publicServiceEligibility(new Date(), serviceAreaId),
        take: 8,
        orderBy: [{ reviewCount: "desc" }, { updatedAt: "desc" }],
        include: serviceInclude(cityId, serviceAreaId)
      }),
      prisma.service.findMany({
        where: { ...publicServiceEligibility(new Date(), serviceAreaId), OR: [{ featured: true }, { popular: true }] },
        take: 8,
        orderBy: [{ rating: "desc" }, { reviewCount: "desc" }],
        include: serviceInclude(cityId, serviceAreaId)
      })
    ]);

    return {
      categories,
      featuredServices,
      popularServices,
      trendingServices,
      recommendedServices
    };
  });
}

async function getHomeCatalog(cityId?: string, userId?: string, pincode?: string) {
  const serviceAreaId = await resolveServiceAreaIds(pincode);
  const sections = await getHomeCatalogSections(cityId, pincode);
  const recentBookings = userId
    ? await prisma.booking.findMany({
        where: { customerId: userId },
        take: 6,
        orderBy: [{ createdAt: "desc" }],
        include: {
          services: {
            include: {
              service: {
                include: serviceInclude(cityId, serviceAreaId)
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

async function resolveHomeServiceSections(cityId?: string, pincode?: string) {
  const serviceAreaId = await resolveServiceAreaIds(pincode);
  const sections = await prisma.homeServiceSection.findMany({
    where: {
      isActive: true,
      items: { some: { service: publicServiceEligibility(new Date(), serviceAreaId) } },
    },
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    include: {
      items: {
        where: { service: publicServiceEligibility(new Date(), serviceAreaId) },
        orderBy: [{ sortOrder: "asc" }],
        include: {
          service: { include: serviceInclude(cityId, serviceAreaId) }
        },
      },
    },
  });

  return sections.map((section) => ({
    id: section.id,
    title: section.title,
    subtitle: section.subtitle,
    sortOrder: section.sortOrder,
    seeAllDestination: section.seeAllDestination,
    services: section.items.map(
      (item: {
        service: Parameters<typeof pickBaseServicePrice>[0] &
          Record<string, unknown>;
      }) => {
        const service = item.service;
        return {
          ...service,
          startingPrice: pickBaseServicePrice(service),
        };
      },
    ),
  }));
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
  availabilityMode?: "INHERITED" | "CUSTOM";
  serviceAreaIds?: string[];
  translations?: Array<Record<string, unknown>>;
}) {
  const rawSlug = data.slug ?? slugify(data.name);
  const slug = await ensureUniqueSlug((candidate) => prisma.serviceCategory.findUnique({ where: { slug: candidate } }), rawSlug);
  const areaIds = data.serviceAreaIds ?? [];
  const availabilityMode = data.availabilityMode ?? (areaIds.length ? "CUSTOM" : "INHERITED");
  if (areaIds.length && await prisma.serviceArea.count({ where: { id: { in: areaIds } } }) !== areaIds.length) {
    throw AppError.badRequest("One or more selected service areas do not exist");
  }
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
      availabilityMode,
      serviceAreaAssignments: availabilityMode === "CUSTOM" && areaIds.length
        ? { create: areaIds.map((serviceAreaId) => ({ serviceAreaId })) }
        : undefined,
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
    include: adminCatalogInclude()
  });

  await invalidateCatalogCache();
  return created;
}

async function updateCategory(id: string, data: Record<string, unknown>) {
  const existing = await prisma.serviceCategory.findUnique({ where: { id } });
  if (!existing) {
    throw AppError.notFound("Category not found");
  }

  const nextSlug = typeof data.slug === "string" ? await ensureUniqueSlug((candidate) => prisma.serviceCategory.findFirst({ where: { slug: candidate, NOT: { id } } }), data.slug) : existing.slug;
  const areaIds = Array.isArray(data.serviceAreaIds)
    ? data.serviceAreaIds.filter((value): value is string => typeof value === "string")
    : undefined;
  if (areaIds?.length && await prisma.serviceArea.count({ where: { id: { in: areaIds } } }) !== areaIds.length) {
    throw AppError.badRequest("One or more selected service areas do not exist");
  }
  const nextMode = data.availabilityMode === "INHERITED" || data.availabilityMode === "CUSTOM"
    ? data.availabilityMode
    : areaIds !== undefined
      ? areaIds.length > 0 ? "CUSTOM" : "INHERITED"
      : undefined;

  await prisma.$transaction(async (tx) => {
    await tx.serviceCategory.update({
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
      popular: typeof data.popular === "boolean" ? data.popular : undefined,
      availabilityMode: nextMode
      }
    });
    if (areaIds !== undefined || nextMode === "INHERITED") {
      await tx.serviceAreaCategory.deleteMany({ where: { categoryId: id } });
      if (nextMode !== "INHERITED" && areaIds?.length) {
        await tx.serviceAreaCategory.createMany({
          data: areaIds.map((serviceAreaId) => ({ categoryId: id, serviceAreaId }))
        });
      }
    }
  });

  await invalidateCatalogCache();
  return prisma.serviceCategory.findUnique({
    where: { id },
    include: adminCatalogInclude()
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
    include: adminCatalogInclude()
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
  availabilityMode?: "INHERITED" | "CUSTOM";
  serviceAreaIds?: string[];
  translations?: Array<Record<string, unknown>>;
}) {
  const rawSlug = data.slug ?? slugify(data.name);
  const slug = await ensureUniqueSlug((candidate) => prisma.serviceSubcategory.findUnique({ where: { slug: candidate } }), rawSlug);
  const areaIds = data.serviceAreaIds ?? [];
  const availabilityMode = data.availabilityMode ?? (areaIds.length ? "CUSTOM" : "INHERITED");
  if (areaIds.length && await prisma.serviceArea.count({ where: { id: { in: areaIds } } }) !== areaIds.length) {
    throw AppError.badRequest("One or more selected service areas do not exist");
  }
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
      availabilityMode,
      serviceAreaAssignments: availabilityMode === "CUSTOM" && areaIds.length
        ? { create: areaIds.map((serviceAreaId) => ({ serviceAreaId })) }
        : undefined,
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
    throw AppError.notFound("Subcategory not found");
  }

  const nextSlug = typeof data.slug === "string" ? await ensureUniqueSlug((candidate) => prisma.serviceSubcategory.findFirst({ where: { slug: candidate, NOT: { id } } }), data.slug) : existing.slug;
  const areaIds = Array.isArray(data.serviceAreaIds)
    ? data.serviceAreaIds.filter((value): value is string => typeof value === "string")
    : undefined;
  if (areaIds?.length && await prisma.serviceArea.count({ where: { id: { in: areaIds } } }) !== areaIds.length) {
    throw AppError.badRequest("One or more selected service areas do not exist");
  }
  const nextMode = data.availabilityMode === "INHERITED" || data.availabilityMode === "CUSTOM"
    ? data.availabilityMode
    : areaIds !== undefined
      ? areaIds.length > 0 ? "CUSTOM" : "INHERITED"
      : undefined;

  await prisma.$transaction(async (tx) => {
    await tx.serviceSubcategory.update({
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
      isActive: typeof data.isActive === "boolean" ? data.isActive : undefined,
      availabilityMode: nextMode
      }
    });
    if (areaIds !== undefined || nextMode === "INHERITED") {
      await tx.serviceAreaSubcategory.deleteMany({ where: { subcategoryId: id } });
      if (nextMode !== "INHERITED" && areaIds?.length) {
        await tx.serviceAreaSubcategory.createMany({
          data: areaIds.map((serviceAreaId) => ({ subcategoryId: id, serviceAreaId }))
        });
      }
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
  requiresSiteVisit?: boolean;
  bookingEnabled?: boolean;
  publicationStatus?: "DRAFT" | "PUBLISHED" | "ARCHIVED";
  publishStartsAt?: string | null;
  publishEndsAt?: string | null;
  availabilityMode?: "INHERITED" | "CUSTOM";
  serviceAreaIds?: string[];
  maintenanceEnabled?: boolean;
  maintenanceIntervalsMonths?: number[];
  maintenanceReminderHours?: number;
  priceType?: string;
  ctaLabel?: string;
  warrantyText?: string | null;
  guaranteeEnabled?: boolean;
  guaranteeClaimWindowDays?: number;
  guaranteeIssueCategories?: string[];
  guaranteeTerms?: string | null;
  guaranteeExclusions?: string | null;
  guaranteeResolutionTypes?: string[];
  guaranteeRequiresPartnerReview?: boolean;
  guaranteeEvidenceRequired?: boolean;
  requirements?: string[];
  isActive?: boolean;
  featured?: boolean;
  popular?: boolean;
  rating?: number;
  reviewCount?: number;
  cancellationPolicy?: string;
  inclusions?: string[];
  exclusions?: string[];
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
  variants?: Array<Record<string, unknown>>;
  addons?: Array<Record<string, unknown>>;
}) {
  const rawSlug = data.slug ?? slugify(data.name);
  const slug = await ensureUniqueSlug((candidate) => prisma.service.findUnique({ where: { slug: candidate } }), rawSlug);
  const code = data.code ?? uniqueCode("SRV", data.name);
  const publishStartsAt = data.publishStartsAt ? new Date(data.publishStartsAt) : null;
  const publishEndsAt = data.publishEndsAt ? new Date(data.publishEndsAt) : null;
  const serviceAvailabilityMode = data.availabilityMode ?? (data.serviceAreaIds?.length ? "CUSTOM" : "INHERITED");

  if (publishStartsAt && publishEndsAt && publishEndsAt <= publishStartsAt) {
    throw AppError.badRequest("Publish end time must be later than publish start time");
  }

  if (data.serviceAreaIds?.length) {
    const areaCount = await prisma.serviceArea.count({
      where: { id: { in: data.serviceAreaIds } }
    });
    if (areaCount !== data.serviceAreaIds.length) {
      throw AppError.badRequest("One or more selected service areas do not exist");
    }
  }
  const variantAreaIds = (data.variants ?? []).flatMap((variant) =>
    Array.isArray(variant.serviceAreaIds)
      ? variant.serviceAreaIds.filter((id): id is string => typeof id === "string")
      : []
  );
  if (variantAreaIds.length && await prisma.serviceArea.count({
    where: { id: { in: [...new Set(variantAreaIds)] } }
  }) !== new Set(variantAreaIds).size) {
    throw AppError.badRequest("One or more selected variant service areas do not exist");
  }

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
      requiresSiteVisit: data.requiresSiteVisit ?? false,
      bookingEnabled: data.bookingEnabled ?? true,
      publicationStatus: data.publicationStatus ?? "PUBLISHED",
      availabilityMode: serviceAvailabilityMode,
      maintenanceEnabled: data.maintenanceEnabled ?? false,
      maintenanceIntervalsMonths: data.maintenanceEnabled ? (data.maintenanceIntervalsMonths ?? []) : [],
      maintenanceReminderHours: data.maintenanceReminderHours ?? 24,
      publishStartsAt: publishStartsAt ?? undefined,
      publishEndsAt: publishEndsAt ?? undefined,
      priceType: data.priceType ?? "FROM",
      ctaLabel: data.ctaLabel ?? "Book service",
      warrantyText: data.warrantyText,
      guaranteeEnabled: data.guaranteeEnabled ?? false,
      guaranteeClaimWindowDays: data.guaranteeClaimWindowDays ?? 0,
      guaranteeIssueCategories: data.guaranteeIssueCategories ?? [],
      guaranteeTerms: data.guaranteeTerms ?? null,
      guaranteeExclusions: data.guaranteeExclusions ?? null,
      guaranteeResolutionTypes: data.guaranteeResolutionTypes ?? [],
      guaranteeRequiresPartnerReview: data.guaranteeRequiresPartnerReview ?? false,
      guaranteeEvidenceRequired: data.guaranteeEvidenceRequired ?? false,
      requirements: data.requirements ?? [],
      isActive: data.isActive ?? true,
      featured: data.featured ?? false,
      popular: data.popular ?? false,
      rating: new Prisma.Decimal(data.rating ?? 0),
      reviewCount: data.reviewCount ?? 0,
      cancellationPolicy: data.cancellationPolicy,
      inclusions: data.inclusions ?? [],
      exclusions: data.exclusions ?? [],
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
      variants: data.variants
        ? {
            create: data.variants.map((item, index) => ({
              name: String(item.name),
              description: typeof item.description === "string" ? item.description : undefined,
              imageUrl: typeof item.imageUrl === "string" ? item.imageUrl : undefined,
              price: new Prisma.Decimal(Number(item.price)),
              originalPrice: typeof item.originalPrice === "number" ? new Prisma.Decimal(item.originalPrice) : undefined,
              estimatedDurationMins: typeof item.estimatedDurationMins === "number" ? item.estimatedDurationMins : undefined,
              isAvailable: typeof item.isAvailable === "boolean" ? item.isAvailable : true,
              availabilityMode: item.availabilityMode === "CUSTOM" || item.availabilityMode === "INHERITED"
                ? item.availabilityMode
                : Array.isArray(item.serviceAreaIds) && item.serviceAreaIds.length > 0
                  ? "CUSTOM"
                  : "INHERITED",
              serviceAreaAssignments:
                (item.availabilityMode === "CUSTOM" ||
                  (item.availabilityMode !== "INHERITED" && Array.isArray(item.serviceAreaIds) && item.serviceAreaIds.length > 0))
                ? {
                    create: (Array.isArray(item.serviceAreaIds) ? item.serviceAreaIds : [])
                      .filter((areaId: unknown): areaId is string => typeof areaId === "string")
                      .map((serviceAreaId) => ({ serviceAreaId }))
                  }
                : undefined,
              sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
            }))
          }
        : undefined,
      addons: data.addons
        ? {
            create: data.addons.map((item, index) => ({
              name: String(item.name),
              description: typeof item.description === "string" ? item.description : undefined,
              imageUrl: typeof item.imageUrl === "string" ? item.imageUrl : undefined,
              price: new Prisma.Decimal(Number(item.price)),
              estimatedDurationMins: typeof item.estimatedDurationMins === "number" ? item.estimatedDurationMins : undefined,
              isActive: typeof item.isActive === "boolean" ? item.isActive : true,
              sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
            }))
          }
        : undefined,
      serviceAreaAssignments: serviceAvailabilityMode === "CUSTOM" && data.serviceAreaIds?.length
        ? {
            create: data.serviceAreaIds.map((serviceAreaId) => ({ serviceAreaId }))
          }
        : undefined
    },
    include: serviceInclude()
  });

  await invalidateCatalogCache();
  return created;
}

async function updateService(id: string, data: Record<string, unknown>) {
  const existing = await prisma.service.findUnique({ where: { id } });
  if (!existing) {
    throw AppError.notFound("Service not found");
  }

  const nextMaintenanceEnabled = typeof data.maintenanceEnabled === "boolean"
    ? data.maintenanceEnabled
    : existing.maintenanceEnabled;
  const nextMaintenanceIntervals = Array.isArray(data.maintenanceIntervalsMonths)
    ? data.maintenanceIntervalsMonths.filter((item): item is number => typeof item === "number")
    : data.maintenanceEnabled === false ? [] : existing.maintenanceIntervalsMonths;
  if (nextMaintenanceEnabled && nextMaintenanceIntervals.length === 0) {
    throw AppError.badRequest("Add at least one permitted maintenance interval");
  }

  const nextGuaranteeEnabled = typeof data.guaranteeEnabled === "boolean"
    ? data.guaranteeEnabled
    : existing.guaranteeEnabled;
  const nextGuaranteeWindowDays = typeof data.guaranteeClaimWindowDays === "number"
    ? data.guaranteeClaimWindowDays
    : existing.guaranteeClaimWindowDays;
  const nextGuaranteeIssueCategories = Array.isArray(data.guaranteeIssueCategories)
    ? data.guaranteeIssueCategories.filter((item): item is string => typeof item === "string")
    : existing.guaranteeIssueCategories;
  const nextGuaranteeResolutionTypes = Array.isArray(data.guaranteeResolutionTypes)
    ? data.guaranteeResolutionTypes.filter((item): item is string => typeof item === "string")
    : existing.guaranteeResolutionTypes;
  if (nextGuaranteeEnabled) {
    if (nextGuaranteeWindowDays < 1) {
      throw AppError.badRequest("A covered service needs a claim window of at least one day");
    }
    if (nextGuaranteeIssueCategories.length === 0) {
      throw AppError.badRequest("Add at least one eligible issue category");
    }
    if (nextGuaranteeResolutionTypes.length === 0) {
      throw AppError.badRequest("Select at least one permitted resolution type");
    }
  }

  const nextSlug = typeof data.slug === "string" ? await ensureUniqueSlug((candidate) => prisma.service.findFirst({ where: { slug: candidate, NOT: { id } } }), data.slug) : existing.slug;
  const nextCode = typeof data.code === "string" ? data.code : existing.code;
  const nextPublishStartsAt = data.publishStartsAt === null
    ? null
    : typeof data.publishStartsAt === "string"
      ? new Date(data.publishStartsAt)
      : existing.publishStartsAt;
  const nextPublishEndsAt = data.publishEndsAt === null
    ? null
    : typeof data.publishEndsAt === "string"
      ? new Date(data.publishEndsAt)
      : existing.publishEndsAt;
  if (nextPublishStartsAt && nextPublishEndsAt && nextPublishEndsAt <= nextPublishStartsAt) {
    throw AppError.badRequest("Publish end time must be later than publish start time");
  }

  if (Array.isArray(data.serviceAreaIds)) {
    const areaIds = data.serviceAreaIds.filter((item): item is string => typeof item === "string");
    const areaCount = areaIds.length
      ? await prisma.serviceArea.count({ where: { id: { in: areaIds } } })
      : 0;
    if (areaCount !== areaIds.length) {
      throw AppError.badRequest("One or more selected service areas do not exist");
    }
  }
  const variantsWithAreas = Array.isArray(data.variants) ? data.variants as Array<Record<string, unknown>> : [];
  const variantAreaIds = variantsWithAreas.flatMap((variant) =>
    Array.isArray(variant.serviceAreaIds)
      ? variant.serviceAreaIds.filter((areaId): areaId is string => typeof areaId === "string")
      : []
  );
  if (variantAreaIds.length && await prisma.serviceArea.count({
    where: { id: { in: [...new Set(variantAreaIds)] } }
  }) !== new Set(variantAreaIds).size) {
    throw AppError.badRequest("One or more selected variant service areas do not exist");
  }
  const availabilityMode = data.availabilityMode === "INHERITED" || data.availabilityMode === "CUSTOM"
    ? data.availabilityMode
    : Array.isArray(data.serviceAreaIds)
      ? data.serviceAreaIds.length > 0 ? "CUSTOM" : "INHERITED"
      : undefined;

  await prisma.$transaction(async (tx) => {
    await tx.service.update({
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
        requiresSiteVisit: typeof data.requiresSiteVisit === "boolean" ? data.requiresSiteVisit : undefined,
        bookingEnabled: typeof data.bookingEnabled === "boolean" ? data.bookingEnabled : undefined,
        publicationStatus: typeof data.publicationStatus === "string" ? data.publicationStatus : undefined,
        availabilityMode,
        maintenanceEnabled: typeof data.maintenanceEnabled === "boolean" ? data.maintenanceEnabled : undefined,
        maintenanceIntervalsMonths: Array.isArray(data.maintenanceIntervalsMonths)
          ? data.maintenanceIntervalsMonths.filter((item): item is number => typeof item === "number")
          : data.maintenanceEnabled === false ? [] : undefined,
        maintenanceReminderHours: typeof data.maintenanceReminderHours === "number" ? data.maintenanceReminderHours : undefined,
        publishStartsAt: data.publishStartsAt === null
          ? null
          : typeof data.publishStartsAt === "string"
            ? new Date(data.publishStartsAt)
            : undefined,
        publishEndsAt: data.publishEndsAt === null
          ? null
          : typeof data.publishEndsAt === "string"
            ? new Date(data.publishEndsAt)
            : undefined,
        priceType: typeof data.priceType === "string" ? data.priceType : undefined,
        ctaLabel: typeof data.ctaLabel === "string" ? data.ctaLabel : undefined,
        warrantyText: data.warrantyText === null
          ? null
          : typeof data.warrantyText === "string"
            ? data.warrantyText
            : undefined,
        guaranteeEnabled: typeof data.guaranteeEnabled === "boolean" ? data.guaranteeEnabled : undefined,
        guaranteeClaimWindowDays: typeof data.guaranteeClaimWindowDays === "number" ? data.guaranteeClaimWindowDays : undefined,
        guaranteeIssueCategories: Array.isArray(data.guaranteeIssueCategories) ? data.guaranteeIssueCategories.filter((item): item is string => typeof item === "string") : undefined,
        guaranteeTerms: data.guaranteeTerms === null ? null : typeof data.guaranteeTerms === "string" ? data.guaranteeTerms : undefined,
        guaranteeExclusions: data.guaranteeExclusions === null ? null : typeof data.guaranteeExclusions === "string" ? data.guaranteeExclusions : undefined,
        guaranteeResolutionTypes: Array.isArray(data.guaranteeResolutionTypes) ? data.guaranteeResolutionTypes.filter((item): item is string => typeof item === "string") : undefined,
        guaranteeRequiresPartnerReview: typeof data.guaranteeRequiresPartnerReview === "boolean" ? data.guaranteeRequiresPartnerReview : undefined,
        guaranteeEvidenceRequired: typeof data.guaranteeEvidenceRequired === "boolean" ? data.guaranteeEvidenceRequired : undefined,
        requirements: Array.isArray(data.requirements)
          ? data.requirements.filter((item): item is string => typeof item === "string")
          : undefined,
        isActive: typeof data.isActive === "boolean" ? data.isActive : undefined,
        featured: typeof data.featured === "boolean" ? data.featured : undefined,
        popular: typeof data.popular === "boolean" ? data.popular : undefined,
        rating: typeof data.rating === "number" ? new Prisma.Decimal(data.rating) : undefined,
        reviewCount: typeof data.reviewCount === "number" ? data.reviewCount : undefined,
        cancellationPolicy: typeof data.cancellationPolicy === "string" ? data.cancellationPolicy : undefined,
        inclusions: Array.isArray(data.inclusions)
          ? data.inclusions.filter((item): item is string => typeof item === "string")
          : undefined,
        exclusions: Array.isArray(data.exclusions)
          ? data.exclusions.filter((item): item is string => typeof item === "string")
          : undefined,
        seoTitle: typeof data.seoTitle === "string" ? data.seoTitle : undefined,
        seoDescription: typeof data.seoDescription === "string" ? data.seoDescription : undefined,
        seoKeywords: typeof data.seoKeywords === "string" ? data.seoKeywords : undefined,
        iconUrl: typeof data.iconUrl === "string" ? data.iconUrl : undefined,
        sortOrder: typeof data.sortOrder === "number" ? data.sortOrder : undefined
      }
    });

    if (Array.isArray(data.images)) {
      await tx.serviceImage.deleteMany({ where: { serviceId: id } });
      await tx.serviceImage.createMany({
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
      await tx.serviceRequiredSkill.deleteMany({ where: { serviceId: id } });
      const skillRows = [];
      for (const [index, item] of data.requiredSkills.entries()) {
        skillRows.push({
          serviceId: id,
          skillId: await resolveSkillId(String(item.name), String(item.slug), tx),
          isMandatory: typeof item.isMandatory === "boolean" ? item.isMandatory : true,
          sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
        });
      }
      await tx.serviceRequiredSkill.createMany({ data: skillRows });
    }

    if (Array.isArray(data.requiredTools)) {
      await tx.serviceRequiredTool.deleteMany({ where: { serviceId: id } });
      const toolRows = [];
      for (const [index, item] of data.requiredTools.entries()) {
        toolRows.push({
          serviceId: id,
          toolId: await resolveToolId(String(item.name), String(item.slug), tx),
          isMandatory: typeof item.isMandatory === "boolean" ? item.isMandatory : true,
          sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
        });
      }
      await tx.serviceRequiredTool.createMany({ data: toolRows });
    }

    if (Array.isArray(data.requiredDocuments)) {
      await tx.serviceRequiredDocument.deleteMany({ where: { serviceId: id } });
      await tx.serviceRequiredDocument.createMany({
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
      await tx.serviceTranslation.deleteMany({ where: { serviceId: id } });
      await tx.serviceTranslation.createMany({
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

    if (Array.isArray(data.variants)) {
      const variants = data.variants as Array<Record<string, unknown>>;
      const retainedIds = variants
        .map((item) => item.id)
        .filter((optionId): optionId is string => typeof optionId === "string");
      const ownedVariants = retainedIds.length
        ? await tx.serviceVariant.findMany({
            where: { serviceId: id, id: { in: retainedIds } },
            select: { id: true, availabilityMode: true }
          })
        : [];
      if (ownedVariants.length !== retainedIds.length) {
        throw AppError.badRequest("A selected variant does not belong to this service");
      }
      const existingVariants = new Map(ownedVariants.map((variant) => [variant.id, variant] as const));

      const variantsToRemove = await tx.serviceVariant.findMany({
        where: {
          serviceId: id,
          ...(retainedIds.length ? { id: { notIn: retainedIds } } : {})
        },
        select: { id: true }
      });
      const referencedVariantIds = variantsToRemove.map((variant) => variant.id);
      if (referencedVariantIds.length > 0) {
        const maintenancePlanCount = await tx.maintenancePlan.count({
          where: { variantId: { in: referencedVariantIds } }
        });
        if (maintenancePlanCount > 0) {
          throw AppError.conflict(
            "A service option used by a maintenance plan cannot be removed. Deactivate it instead."
          );
        }
      }

      await tx.serviceVariant.deleteMany({
          where: {
            serviceId: id,
            ...(retainedIds.length ? { id: { notIn: retainedIds } } : {})
          }
      });
      for (const [index, item] of variants.entries()) {
          const optionData = {
            name: String(item.name),
            description: typeof item.description === "string" ? item.description : null,
            imageUrl: typeof item.imageUrl === "string" ? item.imageUrl : null,
            price: new Prisma.Decimal(Number(item.price)),
            originalPrice: typeof item.originalPrice === "number" ? new Prisma.Decimal(item.originalPrice) : null,
            estimatedDurationMins: typeof item.estimatedDurationMins === "number" ? item.estimatedDurationMins : null,
            isAvailable: typeof item.isAvailable === "boolean" ? item.isAvailable : true,
            availabilityMode: item.availabilityMode === "INHERITED" || item.availabilityMode === "CUSTOM"
              ? item.availabilityMode
              : Array.isArray(item.serviceAreaIds)
                ? item.serviceAreaIds.length > 0 ? "CUSTOM" : "INHERITED"
                : existingVariants.get(String(item.id))?.availabilityMode ?? "INHERITED",
            sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
          };
          if (typeof item.id === "string") {
            await tx.serviceVariant.update({ where: { id: item.id }, data: optionData });
            if (Array.isArray(item.serviceAreaIds) || item.availabilityMode === "INHERITED") {
              await tx.serviceAreaVariant.deleteMany({ where: { variantId: item.id } });
              const areaIds = Array.isArray(item.serviceAreaIds)
                ? item.serviceAreaIds.filter((areaId): areaId is string => typeof areaId === "string")
                : [];
              if (optionData.availabilityMode === "CUSTOM" && areaIds.length) {
                await tx.serviceAreaVariant.createMany({
                  data: areaIds.map((serviceAreaId) => ({ variantId: item.id as string, serviceAreaId }))
                });
              }
            }
          } else {
            const variantAreaIds = Array.isArray(item.serviceAreaIds)
              ? item.serviceAreaIds.filter((areaId): areaId is string => typeof areaId === "string")
              : [];
            await tx.serviceVariant.create({
              data: {
                serviceId: id,
                ...optionData,
                serviceAreaAssignments:
                  optionData.availabilityMode === "CUSTOM" && variantAreaIds.length > 0
                  ? { create: variantAreaIds.map((serviceAreaId) => ({ serviceAreaId })) }
                  : undefined
              }
            });
          }
      }
    }

    if (Array.isArray(data.addons)) {
      const addons = data.addons as Array<Record<string, unknown>>;
      const retainedIds = addons
        .map((item) => item.id)
        .filter((optionId): optionId is string => typeof optionId === "string");
      const ownedIds = retainedIds.length
        ? await tx.serviceAddon.findMany({
            where: { serviceId: id, id: { in: retainedIds } },
            select: { id: true }
          })
        : [];
      if (ownedIds.length !== retainedIds.length) {
        throw AppError.badRequest("A selected add-on does not belong to this service");
      }

      await tx.serviceAddon.deleteMany({
          where: {
            serviceId: id,
            ...(retainedIds.length ? { id: { notIn: retainedIds } } : {})
          }
      });
      for (const [index, item] of addons.entries()) {
          const optionData = {
            name: String(item.name),
            description: typeof item.description === "string" ? item.description : null,
            imageUrl: typeof item.imageUrl === "string" ? item.imageUrl : null,
            price: new Prisma.Decimal(Number(item.price)),
            estimatedDurationMins: typeof item.estimatedDurationMins === "number" ? item.estimatedDurationMins : null,
            isActive: typeof item.isActive === "boolean" ? item.isActive : true,
            sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : index
          };
          if (typeof item.id === "string") {
            await tx.serviceAddon.update({ where: { id: item.id }, data: optionData });
          } else {
            await tx.serviceAddon.create({ data: { serviceId: id, ...optionData } });
          }
      }
    }

    if (Array.isArray(data.serviceAreaIds) || availabilityMode === "INHERITED") {
      const areaIds = Array.isArray(data.serviceAreaIds)
        ? data.serviceAreaIds.filter((item): item is string => typeof item === "string")
        : [];
      await tx.serviceAreaService.deleteMany({ where: { serviceId: id } });
      if (availabilityMode !== "INHERITED" && areaIds.length) {
        await tx.serviceAreaService.createMany({
          data: areaIds.map((serviceAreaId) => ({ serviceId: id, serviceAreaId }))
        });
      }
    }
  });

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

const starterCatalog = [
  ["Home Repair", "home-repair", ["Switches & Sockets", "Lighting & Fixtures", "Safety & Wiring"]],
  ["Cleaning", "cleaning", ["Deep Cleaning", "Kitchen Cleaning", "Bathroom Cleaning"]],
  ["Appliance Repair", "appliance-repair", ["AC Units", "Washing Machines", "Refrigerators"]],
  ["Painting", "painting", ["Interior Painting", "Exterior Painting", "Texture & Decor"]],
  ["Electrical", "electrical", ["Fan & Light", "MCB & DB", "Door Bell & CCTV"]],
  ["Plumbing", "plumbing", ["Tap & Faucet", "Leakage & Pipes", "Tank & Pump"]],
  ["Carpentry", "carpentry", ["Furniture Repair", "Door & Window", "Modular Furniture"]],
  ["Home Improvement", "home-improvement", ["False Ceiling", "Wallpaper & Panels", "Flooring & Tiling"]],
  ["Electronics Repair", "electronics-repair", ["TVs & Audio", "Laptops & PCs", "Smart Devices"]],
  ["Automobile", "automobile", ["Two Wheeler", "Four Wheeler", "Battery & Accessories"]],
  ["Beauty & Wellness", "beauty-wellness", ["Hair Care", "Skincare", "Grooming"]],
  ["Laundry", "laundry", ["Wash & Fold", "Dry Cleaning", "Steam Ironing"]],
  ["Moving", "moving", ["Packing", "Truck Loading", "Unpacking"]],
  ["Pest Control", "pest-control", ["Termites", "Cockroaches & Ants", "Mosquitoes"]],
  ["Home Care", "home-care", ["Elder Care", "Patient Care", "Child Care"]]
] as const;
const starterServiceActions = ["Inspection", "Installation", "Repair", "Replacement", "Maintenance"] as const;

async function addMissingStarterCatalog() {
  let categoryCount = 0;
  let subcategoryCount = 0;
  let serviceCount = 0;

  for (const [categoryIndex, [categoryName, categorySlug, subcategoryNames]] of starterCatalog.entries()) {
    let category = await prisma.serviceCategory.findUnique({ where: { slug: categorySlug } });
    if (!category) {
      category = await createCategory({
        name: categoryName,
        slug: categorySlug,
        description: `${categoryName} services for VeeduFix customers.`,
        sortOrder: categoryIndex,
        isActive: false
      });
      categoryCount += 1;
    }

    for (const [subcategoryIndex, subcategoryName] of subcategoryNames.entries()) {
      let subcategory = await prisma.serviceSubcategory.findFirst({
        where: { categoryId: category.id, name: subcategoryName }
      });
      if (!subcategory) {
        subcategory = await createSubcategory({
          categoryId: category.id,
          name: subcategoryName,
          slug: `${categorySlug}-${slugify(subcategoryName)}`,
          description: `${subcategoryName} under ${categoryName}.`,
          basePrice: 299 + categoryIndex * 40 + subcategoryIndex * 25,
          sortOrder: subcategoryIndex,
          isActive: false
        });
        subcategoryCount += 1;
      }

      for (const [serviceIndex, action] of starterServiceActions.entries()) {
        const serviceName = `${subcategoryName} ${action}`;
        const existingService = await prisma.service.findFirst({
          where: { subcategoryId: subcategory.id, name: serviceName }
        });
        if (existingService) {
          continue;
        }
        await createService({
          categoryId: category.id,
          subcategoryId: subcategory.id,
          name: serviceName,
          slug: `${categorySlug}-${slugify(subcategoryName)}-${action.toLowerCase()}`,
          description: `Professional ${serviceName.toLowerCase()} delivered by verified VeeduFix experts.`,
          shortDescription: `Reliable ${serviceName.toLowerCase()}.`,
          startingPrice: 299 + categoryIndex * 45 + subcategoryIndex * 35 + serviceIndex * 40,
          estimatedDurationMins: 30 + serviceIndex * 20,
          warrantyDays: 7 + serviceIndex * 7,
          emergencyAvailable: serviceIndex % 2 === 0,
          featured: serviceIndex === 0,
          popular: serviceIndex <= 2,
          sortOrder: serviceIndex,
          isActive: false
        });
        serviceCount += 1;
      }
    }
  }

  return { categoryCount, subcategoryCount, serviceCount };
}

async function bulkSetCatalogActiveStatus(input: {
  entityType: "categories" | "subcategories" | "services";
  ids: string[];
  isActive: boolean;
}) {
  const uniqueIds = [...new Set(input.ids)];
  const result = await prisma.$transaction(async (tx) => {
    switch (input.entityType) {
      case "categories":
        return tx.serviceCategory.updateMany({ where: { id: { in: uniqueIds } }, data: { isActive: input.isActive } });
      case "subcategories":
        return tx.serviceSubcategory.updateMany({ where: { id: { in: uniqueIds } }, data: { isActive: input.isActive } });
      case "services":
        return tx.service.updateMany({ where: { id: { in: uniqueIds } }, data: { isActive: input.isActive } });
    }
  });
  await invalidateCatalogCache();
  return { updatedCount: result.count };
}

async function bulkUpdateCatalogAvailability(input: {
  action: "APPLY_LOCATIONS" | "COPY_SERVICE" | "APPLY_CATEGORY" | "REMOVE_LOCATIONS" | "COPY_CATEGORY";
  serviceIds?: string[];
  serviceAreaIds?: string[];
  sourceServiceId?: string;
  categoryId?: string;
  sourceCategoryId?: string;
  targetCategoryId?: string;
}) {
  const result = await prisma.$transaction(async (tx) => {
    if (input.action === "APPLY_LOCATIONS") {
      const serviceIds = input.serviceIds ?? [];
      const areaIds = input.serviceAreaIds ?? [];
      const [serviceCount, areaCount] = await Promise.all([
        tx.service.count({ where: { id: { in: serviceIds } } }),
        tx.serviceArea.count({ where: { id: { in: areaIds } } })
      ]);
      if (serviceCount !== serviceIds.length || areaCount !== areaIds.length) {
        throw AppError.badRequest("One or more selected services or locations no longer exist");
      }
      await tx.service.updateMany({ where: { id: { in: serviceIds } }, data: { availabilityMode: "CUSTOM" } });
      await tx.serviceAreaService.deleteMany({ where: { serviceId: { in: serviceIds } } });
      await tx.serviceAreaService.createMany({
        data: serviceIds.flatMap((serviceId) => areaIds.map((serviceAreaId) => ({ serviceId, serviceAreaId })))
      });
      return { updatedCount: serviceIds.length, assignmentCount: serviceIds.length * areaIds.length };
    }

    if (input.action === "REMOVE_LOCATIONS") {
      const serviceIds = input.serviceIds ?? [];
      const areaIds = input.serviceAreaIds ?? [];
      const [serviceCount, areaCount] = await Promise.all([
        tx.service.count({ where: { id: { in: serviceIds } } }),
        tx.serviceArea.count({ where: { id: { in: areaIds } } })
      ]);
      if (serviceCount !== serviceIds.length || areaCount !== areaIds.length) {
        throw AppError.badRequest("One or more selected services or locations no longer exist");
      }
      const serviceResults = await tx.service.findMany({
        where: { id: { in: serviceIds } },
        select: {
          id: true,
          availabilityMode: true,
          serviceAreaAssignments: { select: { serviceAreaId: true } },
          subcategory: {
            select: {
              availabilityMode: true,
              serviceAreaAssignments: { select: { serviceAreaId: true } },
              category: {
                select: {
                  availabilityMode: true,
                  serviceAreaAssignments: { select: { serviceAreaId: true } }
                }
              }
            }
          }
        }
      });
      if (serviceResults.length !== serviceIds.length) {
        throw AppError.badRequest("One or more selected services no longer exist");
      }

      type AvailabilityAssignments = { serviceAreaId: string }[];
      const services = serviceResults as Array<{
        id: string;
        availabilityMode: string;
        serviceAreaAssignments: AvailabilityAssignments;
        subcategory: {
          availabilityMode: string;
          serviceAreaAssignments: AvailabilityAssignments;
          category: {
            availabilityMode: string;
            serviceAreaAssignments: AvailabilityAssignments;
          };
        };
      }>;
      const inheritedServices = services.filter((service) => service.availabilityMode !== "CUSTOM");
      const needsAllActiveAreas = inheritedServices.some((service) =>
        service.subcategory.availabilityMode !== "CUSTOM" &&
        service.subcategory.category.availabilityMode !== "CUSTOM"
      );
      let allActiveAreaIds: string[] = [];
      if (needsAllActiveAreas) {
        const activeAreas = await tx.serviceArea.findMany({
          where: { isActive: true, city: { isActive: true } },
          select: { id: true },
          take: MAX_MATERIALIZED_REMOVE_AREAS + 1
        });
        if (activeAreas.length > MAX_MATERIALIZED_REMOVE_AREAS) {
          throw AppError.badRequest(
            "Cannot remove locations from inherited services because unrestricted availability spans too many active areas. Set the services to Custom first."
          );
        }
        allActiveAreaIds = activeAreas.map((area) => area.id);
      }

      const areasToRemove = new Set(areaIds);
      const customServiceIds = services
        .filter((service) => service.availabilityMode === "CUSTOM")
        .map((service) => service.id);
      const removedCustom = customServiceIds.length
        ? await tx.serviceAreaService.deleteMany({
            where: {
              serviceId: { in: customServiceIds },
              serviceAreaId: { in: areaIds }
            }
          })
        : { count: 0 };

      let removedInheritedCount = 0;
      const inheritedAssignments: Array<{ serviceId: string; serviceAreaId: string }> = [];
      for (const service of inheritedServices) {
        const effectiveAreaIds = service.subcategory.availabilityMode === "CUSTOM"
          ? service.subcategory.serviceAreaAssignments.map((assignment) => assignment.serviceAreaId)
          : service.subcategory.category.availabilityMode === "CUSTOM"
            ? service.subcategory.category.serviceAreaAssignments.map((assignment) => assignment.serviceAreaId)
            : allActiveAreaIds;
        if (effectiveAreaIds.length > MAX_MATERIALIZED_REMOVE_AREAS) {
          throw AppError.badRequest(
            "Cannot remove locations from inherited services because inherited availability spans too many areas. Set the services to Custom first."
          );
        }
        const uniqueAreaIds = [...new Set(effectiveAreaIds)];
        const remainingAreaIds = uniqueAreaIds.filter((serviceAreaId) => !areasToRemove.has(serviceAreaId));
        if (inheritedAssignments.length + remainingAreaIds.length > 5000) {
          throw AppError.badRequest(
            "This removal would create more than 5,000 service-location assignments. Select fewer services."
          );
        }
        removedInheritedCount += uniqueAreaIds.length - remainingAreaIds.length;
        inheritedAssignments.push(
          ...remainingAreaIds.map((serviceAreaId) => ({ serviceId: service.id, serviceAreaId }))
        );
      }

      if (inheritedServices.length > 0) {
        const inheritedServiceIds = inheritedServices.map((service) => service.id);
        await tx.serviceAreaService.deleteMany({ where: { serviceId: { in: inheritedServiceIds } } });
        await tx.service.updateMany({
          where: { id: { in: inheritedServiceIds } },
          data: { availabilityMode: "CUSTOM" }
        });
        if (inheritedAssignments.length > 0) {
          await tx.serviceAreaService.createMany({ data: inheritedAssignments });
        }
      }

      return {
        updatedCount: serviceIds.length,
        removedAssignmentCount: removedCustom.count + removedInheritedCount
      };
    }

    if (input.action === "COPY_SERVICE") {
      const sourceResult = await tx.service.findUnique({
        where: { id: input.sourceServiceId },
        select: { id: true, availabilityMode: true, serviceAreaAssignments: { select: { serviceAreaId: true } } }
      });
      const source = sourceResult as {
        id: string;
        availabilityMode: string;
        serviceAreaAssignments: Array<{ serviceAreaId: string }>;
      } | null;
      const targetIds = input.serviceIds ?? [];
      const targetCount = await tx.service.count({ where: { id: { in: targetIds } } });
      if (!source || targetCount !== targetIds.length) {
        throw AppError.badRequest("The source or one of the target services no longer exists");
      }
      if (targetIds.includes(source.id)) {
        throw AppError.badRequest("Choose target services other than the source service");
      }
      const copiedCount = source.availabilityMode === "CUSTOM"
        ? targetIds.length * source.serviceAreaAssignments.length
        : 0;
      if (copiedCount > 5000) {
        throw AppError.badRequest(
          "A bulk update may create at most 5,000 service-location assignments"
        );
      }
      await tx.service.updateMany({ where: { id: { in: targetIds } }, data: { availabilityMode: source.availabilityMode } });
      await tx.serviceAreaService.deleteMany({ where: { serviceId: { in: targetIds } } });
      const copiedAreaIds = source.serviceAreaAssignments.map((assignment) => assignment.serviceAreaId);
      if (source.availabilityMode === "CUSTOM" && copiedAreaIds.length > 0) {
        await tx.serviceAreaService.createMany({
          data: targetIds.flatMap((serviceId) => copiedAreaIds.map((serviceAreaId) => ({ serviceId, serviceAreaId })))
        });
      }
      return { updatedCount: targetIds.length, copiedAreaCount: source.availabilityMode === "CUSTOM" ? copiedAreaIds.length : 0 };
    }

    if (input.action === "APPLY_CATEGORY") {
      const categoryResult = await tx.serviceCategory.findUnique({
        where: { id: input.categoryId },
        select: { id: true, subcategories: { select: { id: true, catalogServices: { select: { id: true, variants: { select: { id: true } } } } } } }
      });
      const category = categoryResult as {
        id: string;
        subcategories: Array<{
          id: string;
          catalogServices: Array<{ id: string; variants: Array<{ id: string }> }>;
        }>;
      } | null;
      if (!category) throw AppError.notFound("Category not found");
      const subcategoryIds = category.subcategories.map((subcategory) => subcategory.id);
      const services = category.subcategories.flatMap((subcategory) => subcategory.catalogServices);
      const serviceIds = services.map((service) => service.id);
      const variantIds = services.flatMap((service) => service.variants.map((variant) => variant.id));
      await tx.serviceSubcategory.updateMany({ where: { id: { in: subcategoryIds } }, data: { availabilityMode: "INHERITED" } });
      await tx.service.updateMany({ where: { id: { in: serviceIds } }, data: { availabilityMode: "INHERITED" } });
      await tx.serviceVariant.updateMany({ where: { id: { in: variantIds } }, data: { availabilityMode: "INHERITED" } });
      await tx.serviceAreaSubcategory.deleteMany({ where: { subcategoryId: { in: subcategoryIds } } });
      await tx.serviceAreaService.deleteMany({ where: { serviceId: { in: serviceIds } } });
      await tx.serviceAreaVariant.deleteMany({ where: { variantId: { in: variantIds } } });
      return { updatedCount: subcategoryIds.length + serviceIds.length + variantIds.length, subcategoryCount: subcategoryIds.length, serviceCount: serviceIds.length, variantCount: variantIds.length };
    }

    const sourceResult = await tx.serviceCategory.findUnique({
      where: { id: input.sourceCategoryId },
      select: { id: true, availabilityMode: true, serviceAreaAssignments: { select: { serviceAreaId: true } } }
    });
    const source = sourceResult as {
      id: string;
      availabilityMode: string;
      serviceAreaAssignments: Array<{ serviceAreaId: string }>;
    } | null;
    if (!source || !input.targetCategoryId) {
      throw AppError.badRequest("The source or target category no longer exists");
    }
    if (source.id === input.targetCategoryId) throw AppError.badRequest("Choose a different target category");
    const target = await tx.serviceCategory.findUnique({ where: { id: input.targetCategoryId }, select: { id: true } });
    if (!target) throw AppError.notFound("Target category not found");
    await tx.serviceCategory.update({
      where: { id: target.id },
      data: { availabilityMode: source.availabilityMode }
    });
    await tx.serviceAreaCategory.deleteMany({ where: { categoryId: target.id } });
    const areaIds = source.serviceAreaAssignments.map((assignment) => assignment.serviceAreaId);
    if (source.availabilityMode === "CUSTOM" && areaIds.length > 0) {
      await tx.serviceAreaCategory.createMany({
        data: areaIds.map((serviceAreaId) => ({ categoryId: target.id, serviceAreaId }))
      });
    }
    return { updatedCount: 1, copiedAreaCount: source.availabilityMode === "CUSTOM" ? areaIds.length : 0 };
  });
  await invalidateCatalogCache();
  return { action: input.action, ...result };
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
  resolveAdminCatalogTree,
  resolveCategoryBySlug,
  resolveSubcategoryBySlug,
  resolveServiceBySlug,
  searchCatalog,
  getAutocompleteSuggestions,
  getHomeCatalog,
  resolveHomeServiceSections,
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
  importCatalog,
  addMissingStarterCatalog,
  bulkSetCatalogActiveStatus,
  bulkUpdateCatalogAvailability
};
