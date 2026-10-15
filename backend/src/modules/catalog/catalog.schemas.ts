import { z } from "zod";

const slug = z
  .string()
  .min(2)
  .max(120)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Slug must be lowercase kebab-case");

const optionalSlug = slug.optional();

const locale = z.string().min(2).max(12).default("en");

const id = z.string().min(1);
const pincode = z.string().regex(/^[1-9][0-9]{5}$/).optional();
const availabilityMode = z.enum(["INHERITED", "CUSTOM"]).optional();
const serviceAreaIds = z.array(id).max(500).refine(
  (ids) => new Set(ids).size === ids.length,
  "Service areas cannot be selected more than once"
).optional();

function validateServiceFeatureConfiguration(
  body: {
    maintenanceEnabled?: boolean;
    maintenanceIntervalsMonths?: number[];
    guaranteeEnabled?: boolean;
    guaranteeClaimWindowDays?: number;
    guaranteeIssueCategories?: string[];
    guaranteeResolutionTypes?: string[];
  },
  context: z.RefinementCtx,
  partial = false
) {
  if (
    body.maintenanceEnabled === true &&
    (!partial || body.maintenanceIntervalsMonths !== undefined) &&
    !body.maintenanceIntervalsMonths?.length
  ) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["maintenanceIntervalsMonths"],
      message: "Add at least one permitted maintenance interval"
    });
  }
  if (body.guaranteeEnabled === true) {
    if (
      (!partial || body.guaranteeClaimWindowDays !== undefined) &&
      (!body.guaranteeClaimWindowDays || body.guaranteeClaimWindowDays < 1)
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["guaranteeClaimWindowDays"],
        message: "A covered service needs a claim window of at least one day"
      });
    }
    if (
      (!partial || body.guaranteeIssueCategories !== undefined) &&
      !body.guaranteeIssueCategories?.length
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["guaranteeIssueCategories"],
        message: "Add at least one eligible issue category"
      });
    }
    if (
      (!partial || body.guaranteeResolutionTypes !== undefined) &&
      !body.guaranteeResolutionTypes?.length
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["guaranteeResolutionTypes"],
        message: "Select at least one permitted resolution type"
      });
    }
  }
}

const translationSchema = z.object({
  locale: z.string().min(2).max(12).default("en"),
  name: z.string().min(2).max(160),
  description: z.string().max(5000).optional(),
  shortDescription: z.string().max(500).optional(),
  seoTitle: z.string().max(160).optional(),
  seoDescription: z.string().max(300).optional()
});

const imageSchema = z.object({
  url: z.string().url(),
  altText: z.string().max(200).optional(),
  sortOrder: z.number().int().min(0).optional(),
  isPrimary: z.boolean().optional()
});

const priceRuleSchema = z.object({
  cityId: z.string().optional(),
  type: z.enum(["BASE", "CITY", "SEASONAL", "PROMOTIONAL", "SURGE", "WORKER"]),
  title: z.string().min(2).max(160),
  description: z.string().max(500).optional(),
  currency: z.string().min(3).max(3).default("INR"),
  price: z.number().positive(),
  startsAt: z.string().datetime().optional(),
  endsAt: z.string().datetime().optional(),
  isActive: z.boolean().optional(),
  priority: z.number().int().min(0).optional()
});

const requirementSchema = z.object({
  name: z.string().min(2).max(160),
  slug: slug,
  isMandatory: z.boolean().optional(),
  sortOrder: z.number().int().min(0).optional()
});

const serviceVariantSchema = z.object({
  id: id.optional(),
  name: z.string().trim().min(2).max(120),
  description: z.string().max(1000).nullable().optional(),
  imageUrl: z.string().url().nullable().optional(),
  price: z.number().nonnegative(),
  originalPrice: z.number().nonnegative().nullable().optional(),
  estimatedDurationMins: z.number().int().positive().nullable().optional(),
  isAvailable: z.boolean().optional(),
  availabilityMode,
  serviceAreaIds,
  sortOrder: z.number().int().min(0).optional()
}).superRefine((variant, context) => {
  if (variant.originalPrice != null && variant.originalPrice <= variant.price) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["originalPrice"],
      message: "Original price must be greater than the current price"
    });
  }
});

const serviceAddonSchema = z.object({
  id: id.optional(),
  name: z.string().trim().min(2).max(120),
  description: z.string().max(1000).nullable().optional(),
  imageUrl: z.string().url().nullable().optional(),
  price: z.number().nonnegative(),
  estimatedDurationMins: z.number().int().positive().nullable().optional(),
  isActive: z.boolean().optional(),
  sortOrder: z.number().int().min(0).optional()
});

function uniqueOptionNames<T extends { name: string; id?: string }>(options: T[]) {
  const names = options.map((option) => option.name.trim().toLocaleLowerCase());
  const ids = options.flatMap((option) => option.id ? [option.id] : []);
  return new Set(names).size === names.length && new Set(ids).size === ids.length;
}

export const catalogListQuerySchema = z.object({
  query: z.object({
    locale: locale.optional(),
    cityId: z.string().optional(),
    pincode,
    q: z.string().trim().max(120).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20)
  })
});

export const catalogSlugParamsSchema = z.object({
  params: z.object({
    slug
  }),
  query: z.object({
    locale: locale.optional(),
    cityId: z.string().optional(),
    pincode
  }).optional()
});

export const catalogSearchQuerySchema = z.object({
  query: z.object({
    q: z.string().trim().min(1).max(120).optional(),
    locale: locale.optional(),
    cityId: z.string().optional(),
    pincode,
    categorySlug: z.string().trim().min(1).max(120).optional(),
    subcategorySlug: z.string().trim().min(1).max(120).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
    limit: z.coerce.number().int().min(1).max(50).default(12)
  })
});

export const autocompleteCatalogQuerySchema = z.object({
  query: z.object({
    q: z.string().trim().min(1).max(120),
    cityId: z.string().optional(),
    pincode,
    limit: z.coerce.number().int().min(1).max(50).default(12)
  })
});

export const reorderCategoriesSchema = z.object({
  body: z.object({
    ids: z.array(id).min(1)
  })
});

export const reorderSubcategoriesSchema = z.object({
  body: z.object({
    categoryId: id,
    ids: z.array(id).min(1)
  })
});

export const reorderServicesSchema = z.object({
  body: z.object({
    subcategoryId: id,
    ids: z.array(id).min(1)
  })
});

export const createCategorySchema = z.object({
  body: z.object({
    name: z.string().min(2).max(160),
    slug: optionalSlug,
    description: z.string().max(5000).optional(),
    iconUrl: z.string().url().optional(),
    seoTitle: z.string().max(160).optional(),
    seoDescription: z.string().max(300).optional(),
    sortOrder: z.number().int().min(0).optional(),
    isActive: z.boolean().optional(),
    featured: z.boolean().optional(),
    popular: z.boolean().optional(),
    availabilityMode,
    serviceAreaIds,
    translations: z.array(translationSchema).optional()
  })
});

export const updateCategorySchema = z.object({
  params: z.object({
    id
  }),
  body: createCategorySchema.shape.body.partial()
});

export const createSubcategorySchema = z.object({
  body: z.object({
    categoryId: id,
    name: z.string().min(2).max(160),
    slug: optionalSlug,
    description: z.string().max(5000).optional(),
    iconUrl: z.string().url().optional(),
    seoTitle: z.string().max(160).optional(),
    seoDescription: z.string().max(300).optional(),
    basePrice: z.number().nonnegative().optional(),
    sortOrder: z.number().int().min(0).optional(),
    rating: z.number().min(0).max(5).optional(),
    reviewCount: z.number().int().min(0).optional(),
    isActive: z.boolean().optional(),
    availabilityMode,
    serviceAreaIds,
    translations: z.array(translationSchema).optional()
  })
});

export const updateSubcategorySchema = z.object({
  params: z.object({
    id
  }),
  body: createSubcategorySchema.shape.body.partial()
});

export const createServiceSchema = z.object({
  body: z.object({
    categoryId: id,
    subcategoryId: id,
    name: z.string().min(2).max(160),
    slug: optionalSlug,
    code: z.string().min(2).max(80).optional(),
    description: z.string().max(10000).optional(),
    shortDescription: z.string().max(500).optional(),
    startingPrice: z.number().positive(),
    gstRate: z.number().positive().default(18),
    sacCode: z.string().max(80).optional(),
    estimatedDurationMins: z.number().int().positive(),
    warrantyDays: z.number().int().min(0).optional(),
    gstApplicable: z.boolean().optional(),
    emergencyAvailable: z.boolean().optional(),
    homeVisit: z.boolean().optional(),
    requiresSiteVisit: z.boolean().optional(),
    bookingEnabled: z.boolean().optional(),
    publicationStatus: z.enum(["DRAFT", "PUBLISHED", "ARCHIVED"]).optional(),
    publishStartsAt: z.string().datetime().nullable().optional(),
    publishEndsAt: z.string().datetime().nullable().optional(),
    availabilityMode,
    serviceAreaIds,
    maintenanceEnabled: z.boolean().optional(),
    maintenanceIntervalsMonths: z.array(z.number().int().min(1).max(24)).max(12).refine((items) => new Set(items).size === items.length, "Maintenance intervals must be unique").optional(),
    maintenanceReminderHours: z.number().int().min(1).max(720).optional(),
    priceType: z.enum(["FIXED", "FROM", "QUOTE"]).optional(),
    ctaLabel: z.string().trim().min(2).max(40).optional(),
    warrantyText: z.string().max(1000).nullable().optional(),
    guaranteeEnabled: z.boolean().optional(),
    guaranteeClaimWindowDays: z.number().int().min(0).max(3650).optional(),
    guaranteeIssueCategories: z.array(z.string().trim().min(2).max(60)).max(20).optional(),
    guaranteeTerms: z.string().max(2000).nullable().optional(),
    guaranteeExclusions: z.string().max(2000).nullable().optional(),
    guaranteeResolutionTypes: z.array(z.enum(["REWORK", "REVISIT", "REFUND_REVIEW"])).max(3).optional(),
    guaranteeRequiresPartnerReview: z.boolean().optional(),
    guaranteeEvidenceRequired: z.boolean().optional(),
    requirements: z.array(z.string().trim().min(1).max(300)).max(30).optional(),
    isActive: z.boolean().optional(),
    featured: z.boolean().optional(),
    popular: z.boolean().optional(),
    rating: z.number().min(0).max(5).optional(),
    reviewCount: z.number().int().min(0).optional(),
    cancellationPolicy: z.string().max(2000).optional(),
    inclusions: z.array(z.string().trim().min(1).max(300)).max(50).optional(),
    exclusions: z.array(z.string().trim().min(1).max(300)).max(50).optional(),
    seoTitle: z.string().max(160).optional(),
    seoDescription: z.string().max(300).optional(),
    seoKeywords: z.string().max(500).optional(),
    iconUrl: z.string().url().optional(),
    sortOrder: z.number().int().min(0).optional(),
    translations: z.array(translationSchema).optional(),
    images: z.array(imageSchema).optional(),
    requiredSkills: z.array(requirementSchema).optional(),
    requiredTools: z.array(requirementSchema).optional(),
    requiredDocuments: z.array(requirementSchema).optional(),
    variants: z.array(serviceVariantSchema).max(30).refine(uniqueOptionNames, {
      message: "Variant names must be unique"
    }).optional(),
    addons: z.array(serviceAddonSchema).max(50).refine(uniqueOptionNames, {
      message: "Add-on names must be unique"
    }).optional()
  }).superRefine((body, context) =>
    validateServiceFeatureConfiguration(body, context)
  )
});

const updateServiceBodySchema = createServiceSchema.shape.body
  .innerType()
  .partial()
  .superRefine((body, context) =>
    validateServiceFeatureConfiguration(body, context, true)
  );

export const updateServiceSchema = z.object({
  params: z.object({
    id
  }),
  body: updateServiceBodySchema
});

export const addServiceImagesSchema = z.object({
  params: z.object({
    id
  }),
  body: z.object({
    images: z.array(imageSchema).min(1)
  })
});

export const addServicePricingSchema = z.object({
  params: z.object({
    id
  }),
  body: priceRuleSchema
});

export const updatePriceRuleSchema = z.object({
  params: z.object({
    id
  }),
  body: priceRuleSchema.partial()
});

export const importCatalogSchema = z.object({
  body: z.object({
    categories: z.array(
      z.object({
        name: z.string().min(2).max(160),
        slug: optionalSlug,
        description: z.string().max(5000).optional(),
        iconUrl: z.string().url().optional(),
        sortOrder: z.number().int().min(0).optional(),
        featured: z.boolean().optional(),
        popular: z.boolean().optional(),
        translations: z.array(translationSchema).optional(),
        subcategories: z.array(
          z.object({
            name: z.string().min(2).max(160),
            slug: optionalSlug,
            description: z.string().max(5000).optional(),
            iconUrl: z.string().url().optional(),
            basePrice: z.number().nonnegative().optional(),
            sortOrder: z.number().int().min(0).optional(),
            isActive: z.boolean().optional(),
            translations: z.array(translationSchema).optional(),
            services: z.array(
              z.object({
                name: z.string().min(2).max(160),
                slug: optionalSlug,
                code: z.string().min(2).max(80).optional(),
                description: z.string().max(10000).optional(),
                shortDescription: z.string().max(500).optional(),
                startingPrice: z.number().positive(),
                gstRate: z.number().positive().default(18),
                sacCode: z.string().max(80).optional(),
                estimatedDurationMins: z.number().int().positive(),
                warrantyDays: z.number().int().min(0).optional(),
                gstApplicable: z.boolean().optional(),
                emergencyAvailable: z.boolean().optional(),
                homeVisit: z.boolean().optional(),
                featured: z.boolean().optional(),
                popular: z.boolean().optional(),
                rating: z.number().min(0).max(5).optional(),
                reviewCount: z.number().int().min(0).optional(),
                iconUrl: z.string().url().optional(),
                sortOrder: z.number().int().min(0).optional(),
                translations: z.array(translationSchema).optional(),
                images: z.array(imageSchema).optional(),
                requiredSkills: z.array(requirementSchema).optional(),
                requiredTools: z.array(requirementSchema).optional(),
                requiredDocuments: z.array(requirementSchema).optional()
              })
            ).optional()
          })
        ).optional()
      })
    )
  })
});

export const bulkCatalogStatusSchema = z.object({
  body: z.object({
    entityType: z.enum(["categories", "subcategories", "services"]),
    ids: z.array(id).min(1).max(500),
    isActive: z.boolean()
  })
});

export const adminCatalogExportQuerySchema = z.object({
  query: z.object({
    stateId: id.optional(),
    districtId: id.optional(),
    cityId: id.optional(),
    areaId: id.optional(),
    pincode: z.string().regex(/^[1-9][0-9]{5}$/).optional(),
    categoryId: id.optional(),
    subcategoryId: id.optional(),
    serviceId: id.optional(),
    availabilityStatus: z.enum(["INHERITED", "CUSTOM", "AVAILABLE", "UNAVAILABLE"]).optional(),
    isActive: z.enum(["true", "false"]).optional()
  }).strict().superRefine((query, context) => {
    if (
      (query.availabilityStatus === "AVAILABLE" || query.availabilityStatus === "UNAVAILABLE") &&
      !query.stateId && !query.districtId && !query.cityId && !query.areaId && !query.pincode
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["availabilityStatus"],
        message: "Choose a location to filter by availability"
      });
    }
  }),
  body: z.object({}).strict().optional(),
  params: z.object({}).strict().optional()
});

export const bulkCatalogAvailabilitySchema = z.object({
  body: z.object({
    action: z.enum([
      "APPLY_LOCATIONS",
      "COPY_SERVICE",
      "APPLY_CATEGORY",
      "REMOVE_LOCATIONS",
      "COPY_CATEGORY"
    ]),
    serviceIds: z.array(id).max(500).optional(),
    serviceAreaIds: z.array(id).max(500).optional(),
    sourceServiceId: id.optional(),
    categoryId: id.optional(),
    sourceCategoryId: id.optional(),
    targetCategoryId: id.optional()
  }).strict().superRefine((body, context) => {
    const unique = (values: string[] | undefined, key: string) => {
      if (values && new Set(values).size !== values.length) {
        context.addIssue({ code: z.ZodIssueCode.custom, path: [key], message: `${key} must be unique` });
      }
    };
    unique(body.serviceIds, "serviceIds");
    unique(body.serviceAreaIds, "serviceAreaIds");
    if (["APPLY_LOCATIONS", "COPY_SERVICE", "REMOVE_LOCATIONS"].includes(body.action) && !body.serviceIds?.length) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ["serviceIds"], message: "Select at least one service" });
    }
    if (body.action === "APPLY_LOCATIONS" && !body.serviceAreaIds?.length) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ["serviceAreaIds"], message: "Select at least one location" });
    }
    if (body.action === "REMOVE_LOCATIONS" && !body.serviceAreaIds?.length) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ["serviceAreaIds"], message: "Select locations to remove" });
    }
    if (
      body.action === "APPLY_LOCATIONS" &&
      (body.serviceIds?.length ?? 0) * (body.serviceAreaIds?.length ?? 0) > 5000
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["serviceAreaIds"],
        message: "A bulk update may create at most 5,000 service-location assignments"
      });
    }
    if (body.action === "COPY_SERVICE" && !body.sourceServiceId) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ["sourceServiceId"], message: "Choose a source service" });
    }
    if (body.action === "APPLY_CATEGORY" && !body.categoryId) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ["categoryId"], message: "Choose a category" });
    }
    if (body.action === "COPY_CATEGORY" && (!body.sourceCategoryId || !body.targetCategoryId)) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ["sourceCategoryId"], message: "Choose both source and target categories" });
    }
  }),
  query: z.object({}).strict().optional(),
  params: z.object({}).strict().optional()
});
