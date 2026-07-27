import { z } from "zod";

const slug = z
  .string()
  .min(2)
  .max(120)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Slug must be lowercase kebab-case");

const optionalSlug = slug.optional();

const locale = z.string().min(2).max(12).default("en");

const id = z.string().min(1);

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

export const catalogListQuerySchema = z.object({
  query: z.object({
    locale: locale.optional(),
    cityId: z.string().optional(),
    q: z.string().trim().max(120).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
    includeInactive: z.coerce.boolean().optional()
  })
});

export const catalogSlugParamsSchema = z.object({
  params: z.object({
    slug
  }),
  query: z.object({
    locale: locale.optional(),
    cityId: z.string().optional()
  }).optional()
});

export const catalogSearchQuerySchema = z.object({
  query: z.object({
    q: z.string().trim().min(1).max(120),
    locale: locale.optional(),
    cityId: z.string().optional(),
    limit: z.coerce.number().int().min(1).max(50).default(12)
  })
});

export const reorderCategoriesSchema = z.object({
  body: z.object({
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
    estimatedDurationMins: z.number().int().positive(),
    warrantyDays: z.number().int().min(0).optional(),
    gstApplicable: z.boolean().optional(),
    emergencyAvailable: z.boolean().optional(),
    homeVisit: z.boolean().optional(),
    isActive: z.boolean().optional(),
    featured: z.boolean().optional(),
    popular: z.boolean().optional(),
    rating: z.number().min(0).max(5).optional(),
    reviewCount: z.number().int().min(0).optional(),
    cancellationPolicy: z.string().max(2000).optional(),
    seoTitle: z.string().max(160).optional(),
    seoDescription: z.string().max(300).optional(),
    seoKeywords: z.string().max(500).optional(),
    iconUrl: z.string().url().optional(),
    sortOrder: z.number().int().min(0).optional(),
    translations: z.array(translationSchema).optional(),
    images: z.array(imageSchema).optional(),
    requiredSkills: z.array(requirementSchema).optional(),
    requiredTools: z.array(requirementSchema).optional(),
    requiredDocuments: z.array(requirementSchema).optional()
  })
});

export const updateServiceSchema = z.object({
  params: z.object({
    id
  }),
  body: createServiceSchema.shape.body.partial()
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

