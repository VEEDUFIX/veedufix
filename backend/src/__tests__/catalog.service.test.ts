import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    serviceCategory: { findMany: vi.fn(), findFirst: vi.fn(), findUnique: vi.fn(), create: vi.fn(), count: vi.fn() },
    serviceSubcategory: { findFirst: vi.fn(), findMany: vi.fn(), create: vi.fn(), count: vi.fn(), findUnique: vi.fn() },
    service: { findFirst: vi.fn(), create: vi.fn(), count: vi.fn(), findMany: vi.fn(), findUnique: vi.fn() },
    serviceArea: { count: vi.fn() },
    city: { findFirst: vi.fn() },
    servicePriceRule: { create: vi.fn() },
    $transaction: vi.fn((cb) => cb(prismaMockTx)),
  },
}));

const prismaMockTx = {
  serviceCategory: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn(), findUnique: vi.fn() },
  serviceSubcategory: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn(), findUnique: vi.fn() },
  service: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn(), count: vi.fn(), findMany: vi.fn(), findUnique: vi.fn() },
  serviceCategoryTranslation: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceSubcategoryTranslation: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceTranslation: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceImage: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceRequiredSkill: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceRequiredTool: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceRequiredDocument: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceArea: { count: vi.fn(), findMany: vi.fn() },
  serviceAreaCategory: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceAreaSubcategory: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceAreaService: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceVariant: { create: vi.fn(), update: vi.fn(), findMany: vi.fn(), deleteMany: vi.fn() },
  serviceAreaVariant: { deleteMany: vi.fn(), createMany: vi.fn() },
  serviceAddon: { create: vi.fn(), update: vi.fn(), findMany: vi.fn() },
  servicePriceRule: { create: vi.fn(), update: vi.fn(), findMany: vi.fn() },
  skill: { findUnique: vi.fn(), create: vi.fn() },
  tool: { findUnique: vi.fn(), create: vi.fn() },
  city: { findFirst: vi.fn() },
  maintenancePlan: { count: vi.fn() },
};

vi.mock('../lib/redis.js', () => ({
  redis: {
    get: vi.fn().mockResolvedValue(null),
    set: vi.fn().mockResolvedValue('OK'),
    incr: vi.fn().mockResolvedValue(2),
  },
}));

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
}));

// ─── Imports ──────────────────────────────────────────────────────────────────

import { catalogService } from '../modules/catalog/catalog.service.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';

describe('Catalog Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('updateService policy validation', () => {
    const service = {
      id: 'service-1',
      slug: 'service',
      code: 'SVC-1',
      name: 'Service',
      publishStartsAt: null,
      publishEndsAt: null,
      maintenanceEnabled: true,
      maintenanceIntervalsMonths: [3],
      guaranteeEnabled: true,
      guaranteeClaimWindowDays: 30,
      guaranteeIssueCategories: ['Installation issue'],
      guaranteeResolutionTypes: ['REWORK']
    };

    it('uses saved policy values when enabling a policy with a partial update', async () => {
      vi.mocked(prisma.service.findUnique)
        .mockResolvedValueOnce(service as any)
        .mockResolvedValueOnce({ ...service, guaranteeEnabled: true } as any);
      vi.mocked(prismaMockTx.service.update).mockResolvedValue({ ...service, guaranteeEnabled: true } as any);

      await expect(catalogService.updateService('service-1', { guaranteeEnabled: true }))
        .resolves.toMatchObject({ guaranteeEnabled: true });
      expect(prismaMockTx.service.update).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ guaranteeEnabled: true })
      }));
    });

    it('rejects clearing the final issue category while the saved guarantee remains enabled', async () => {
      vi.mocked(prisma.service.findUnique).mockResolvedValueOnce(service as any);

      await expect(catalogService.updateService('service-1', { guaranteeIssueCategories: [] }))
        .rejects.toMatchObject({ statusCode: 400 });
      expect(prismaMockTx.service.update).not.toHaveBeenCalled();
    });

    it('rejects clearing intervals while the saved maintenance policy remains enabled', async () => {
      vi.mocked(prisma.service.findUnique).mockResolvedValueOnce(service as any);

      await expect(catalogService.updateService('service-1', { maintenanceIntervalsMonths: [] }))
        .rejects.toMatchObject({ statusCode: 400 });
      expect(prismaMockTx.service.update).not.toHaveBeenCalled();
    });
  });

  describe('upsertPriceRule city validation', () => {
    it('requires and validates active cities before persisting a city pricing rule', async () => {
      await expect(catalogService.upsertPriceRule('service-1', {
        type: 'CITY',
        title: 'City price',
        price: 500,
      })).rejects.toMatchObject({ statusCode: 400 });
      expect(prisma.servicePriceRule.create).not.toHaveBeenCalled();

      vi.mocked(prisma.city.findFirst).mockResolvedValueOnce(null as any);
      await expect(catalogService.upsertPriceRule('service-1', {
        type: 'CITY',
        title: 'City price',
        price: 500,
        cityId: 'inactive-city',
      })).rejects.toMatchObject({ statusCode: 400 });
      expect(prisma.servicePriceRule.create).not.toHaveBeenCalled();

      vi.mocked(prisma.city.findFirst).mockResolvedValueOnce({ id: 'city-1' } as any);
      vi.mocked(prisma.servicePriceRule.create).mockResolvedValueOnce({ id: 'rule-1' } as any);
      await expect(catalogService.upsertPriceRule('service-1', {
        type: 'CITY',
        title: 'City price',
        price: 500,
        cityId: 'city-1',
      })).resolves.toMatchObject({ id: 'rule-1' });
      expect(prisma.city.findFirst).toHaveBeenLastCalledWith({
        where: { id: 'city-1', isActive: true },
        select: { id: true },
      });
    });
  });

  describe('importCatalog', () => {
    it('writes the complete import through one transaction', async () => {
      vi.mocked(prismaMockTx.serviceCategory.findUnique).mockResolvedValueOnce(null as any);
      vi.mocked(prismaMockTx.serviceCategory.create).mockResolvedValueOnce({ id: 'category-1' } as any);
      vi.mocked(prismaMockTx.serviceSubcategory.findUnique).mockResolvedValueOnce(null as any);
      vi.mocked(prismaMockTx.serviceSubcategory.create).mockResolvedValueOnce({ id: 'subcategory-1' } as any);
      vi.mocked(prismaMockTx.service.findUnique).mockResolvedValueOnce(null as any);
      vi.mocked(prismaMockTx.service.create).mockResolvedValueOnce({ id: 'service-1' } as any);

      await expect(catalogService.importCatalog([{
        name: 'Plumbing',
        slug: 'plumbing',
        subcategories: [{
          name: 'Leaks',
          slug: 'leaks',
          services: [{
            name: 'Tap repair',
            slug: 'tap-repair',
            startingPrice: 450,
            estimatedDurationMins: 60,
          }],
        }],
      }])).resolves.toEqual({
        categoryCount: 1,
        subcategoryCount: 1,
        serviceCount: 1,
      });

      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
      expect(prismaMockTx.serviceCategory.create).toHaveBeenCalledTimes(1);
      expect(prismaMockTx.serviceSubcategory.create).toHaveBeenCalledTimes(1);
      expect(prismaMockTx.service.create).toHaveBeenCalledTimes(1);
    });

    it('restores exported service policies and child catalog records inside the import transaction', async () => {
      prismaMockTx.serviceCategory.findUnique.mockResolvedValueOnce(null as any);
      prismaMockTx.serviceCategory.create.mockResolvedValueOnce({ id: 'category-1', name: 'Home repair' } as any);
      prismaMockTx.serviceSubcategory.findUnique.mockResolvedValueOnce(null as any);
      prismaMockTx.serviceSubcategory.create.mockResolvedValueOnce({ id: 'subcategory-1', name: 'Plumbing' } as any);
      prismaMockTx.service.findUnique.mockResolvedValueOnce(null as any);
      prismaMockTx.service.create.mockResolvedValueOnce({ id: 'service-1', name: 'Tap repair' } as any);
      prismaMockTx.skill.findUnique.mockResolvedValueOnce(null as any);
      prismaMockTx.skill.create.mockResolvedValueOnce({ id: 'skill-1' } as any);
      prismaMockTx.serviceVariant.findMany.mockResolvedValueOnce([] as any);
      prismaMockTx.serviceVariant.create.mockResolvedValueOnce({ id: 'variant-1' } as any);
      prismaMockTx.serviceAddon.findMany.mockResolvedValueOnce([] as any);
      prismaMockTx.serviceAddon.create.mockResolvedValueOnce({ id: 'addon-1' } as any);
      prismaMockTx.servicePriceRule.findMany.mockResolvedValueOnce([] as any);
      prismaMockTx.servicePriceRule.create.mockResolvedValueOnce({ id: 'rule-1' } as any);

      await catalogService.importCatalog([{
        name: 'Home repair',
        slug: 'home-repair',
        subcategories: [{
          name: 'Plumbing',
          slug: 'plumbing',
          services: [{
            name: 'Tap repair',
            slug: 'tap-repair',
            startingPrice: 450,
            estimatedDurationMins: 60,
            publicationStatus: 'DRAFT',
            bookingEnabled: false,
            maintenanceEnabled: true,
            maintenanceIntervalsMonths: [3],
            guaranteeEnabled: true,
            guaranteeClaimWindowDays: 30,
            guaranteeIssueCategories: ['Installation issue'],
            guaranteeResolutionTypes: ['REWORK'],
            translations: [{ locale: 'en', name: 'Tap repair' }],
            images: [{ url: 'https://example.test/tap.jpg', isPrimary: true }],
            requiredSkills: [{ name: 'Plumbing', slug: 'plumbing' }],
            requiredDocuments: [{ name: 'License', slug: 'license' }],
            variants: [{ name: 'Standard', price: 450 }],
            addons: [{ name: 'Seal replacement', price: 50 }],
            priceRules: [{ type: 'BASE', title: 'Base', price: 450 }],
          }],
        }],
      }]);

      expect(prismaMockTx.service.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({
          publicationStatus: 'DRAFT',
          bookingEnabled: false,
          maintenanceIntervalsMonths: [3],
          guaranteeIssueCategories: ['Installation issue'],
        }),
      }));
      expect(prismaMockTx.serviceTranslation.createMany).toHaveBeenCalled();
      expect(prismaMockTx.serviceImage.createMany).toHaveBeenCalled();
      expect(prismaMockTx.serviceRequiredSkill.createMany).toHaveBeenCalled();
      expect(prismaMockTx.serviceRequiredDocument.createMany).toHaveBeenCalled();
      expect(prismaMockTx.serviceVariant.create).toHaveBeenCalled();
      expect(prismaMockTx.serviceAddon.create).toHaveBeenCalled();
      expect(prismaMockTx.servicePriceRule.create).toHaveBeenCalled();
    });
  });

  describe('resolveCatalogTree', () => {
    it('returns the category tree successfully', async () => {
      const mockCategories = [
        {
          name: 'Home Repair', slug: 'home-repair', isActive: true, sortOrder: 1, translations: [],
          subcategories: [
            {
              name: 'AC Service', slug: 'ac-service', isActive: true, sortOrder: 1, translations: [],
              services: [
                { name: 'AC Cleaning', slug: 'ac-cleaning', isActive: true, sortOrder: 1, translations: [], pricingRules: [] }
              ]
            }
          ]
        }
      ];
      vi.mocked(prisma.serviceCategory.findMany).mockResolvedValue(mockCategories as any);

      const tree = await catalogService.resolveCatalogTree();
      
      expect(tree).toHaveLength(1);
      expect(tree[0].name).toBe('Home Repair');
      expect(tree[0].subcategories![0].name).toBe('AC Service');
      expect(prisma.serviceCategory.findMany).toHaveBeenCalled();
    });
  });

  describe('resolveCategoryBySlug', () => {
    it('returns a category if found', async () => {
      const mockCategory = { name: 'Home Repair', slug: 'home-repair', isActive: true, translations: [] };
      vi.mocked(prisma.serviceCategory.findFirst).mockResolvedValue(mockCategory as any);

      const category = await catalogService.resolveCategoryBySlug('home-repair');
      expect(category.name).toBe('Home Repair');
      expect(prisma.serviceCategory.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            slug: 'home-repair',
            isActive: true,
            subcategories: expect.objectContaining({
              some: expect.objectContaining({
                isActive: true,
                catalogServices: expect.objectContaining({ some: expect.any(Object) })
              })
            })
          }),
          include: expect.objectContaining({
            subcategories: expect.objectContaining({
              where: expect.objectContaining({ isActive: true }),
              orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
            }),
          }),
        }),
      );
    });

    it('returns null if not found', async () => {
      vi.mocked(prisma.serviceCategory.findFirst).mockResolvedValue(null);
      const res = await catalogService.resolveCategoryBySlug('invalid');
      expect(res).toBeNull();
    });
  });

  describe('searchCatalog', () => {
    it('returns paginated search results', async () => {
      vi.mocked(prisma.service.count).mockResolvedValue(1);
      vi.mocked(prisma.service.findMany).mockResolvedValue([{ id: 'service-ac-cleaning', name: 'AC Cleaning', slug: 'ac-cleaning', isActive: true, translations: [], pricingRules: [] }] as any);

      const results = await catalogService.searchCatalog({ q: 'AC', page: 1, pageSize: 10 });
      expect(results.total).toBe(1);
      expect(results.items[0].name).toBe('AC Cleaning');
    });

    it('caps the reported total at the ranked text-search result limit', async () => {
      vi.mocked(prisma.service.count).mockResolvedValue(500);
      vi.mocked(prisma.service.findMany).mockResolvedValue([
        { id: 'service-ac-cleaning', name: 'AC Cleaning', slug: 'ac-cleaning', isActive: true, translations: [], pricingRules: [] }
      ] as any);

      const results = await catalogService.searchCatalog({ q: 'AC', page: 1, pageSize: 10 });

      expect(results.total).toBe(240);
      expect(results.resultLimit).toBe(240);
    });

    it('uses aliases and synonyms while keeping exact text relevance ahead of popularity', async () => {
      vi.mocked(prisma.service.count).mockResolvedValue(2);
      vi.mocked(prisma.service.findMany).mockResolvedValue([
        {
          id: 'home-cleaning', name: 'Home Cleaning', slug: 'home-cleaning', popular: true,
          featured: true, sortOrder: 0, isActive: true, translations: [], pricingRules: []
        },
        {
          id: 'ac-repair', name: 'AC Repair', slug: 'ac-repair', popular: false,
          featured: false, sortOrder: 2, isActive: true, translations: [], pricingRules: []
        }
      ] as any);

      const results = await catalogService.searchCatalog({
        q: 'AC not cooling',
        page: 1,
        pageSize: 10
      });

      expect(results.items.map((item) => item.name)).toEqual(['AC Repair', 'Home Cleaning']);
      const query = vi.mocked(prisma.service.findMany).mock.calls[0][0];
      expect(query?.take).toBe(960);
      expect(query?.select).toMatchObject({ id: true, name: true, popular: true });
      expect(vi.mocked(prisma.service.findMany).mock.calls[1][0]?.include).toBeDefined();
      expect(query?.where).toMatchObject({ isActive: true, publicationStatus: 'PUBLISHED' });
      const searchTerms = (query?.where as any).OR;
      expect(searchTerms).toEqual(expect.arrayContaining([
        expect.objectContaining({ seoKeywords: { contains: 'ac repair', mode: 'insensitive' } })
      ]));
    });
  });

  describe('getAutocompleteSuggestions', () => {
    it('bounds matching service candidates before sorting suggestions', async () => {
      vi.mocked(prisma.service.findMany).mockResolvedValue([
        {
          name: 'AC repair', slug: 'ac-repair', popular: true, reviewCount: 10,
          sortOrder: 0, category: { slug: 'home-services' }, subcategory: { slug: 'air-conditioning' }
        }
      ] as any);
      vi.mocked(prisma.serviceCategory.findMany).mockResolvedValue([] as any);
      vi.mocked(prisma.serviceSubcategory.findMany).mockResolvedValue([] as any);

      const result = await catalogService.getAutocompleteSuggestions('ac', 10);

      expect(result.services).toHaveLength(1);
      expect(prisma.service.findMany).toHaveBeenCalledWith(expect.objectContaining({
        take: 200,
        orderBy: [{ popular: 'desc' }, { reviewCount: 'desc' }, { sortOrder: 'asc' }]
      }));
    });
  });

  describe('createCategory', () => {
    it('creates a category with unique slug', async () => {
      vi.mocked(prisma.serviceCategory.findUnique).mockResolvedValue(null);
      prisma.serviceCategory.create = vi.fn().mockResolvedValue({ id: 'c1', name: 'Plumbing', slug: 'plumbing' } as any);

      const res = await catalogService.createCategory({ name: 'Plumbing', description: 'desc', iconUrl: 'url', seoTitle: '', seoDescription: '', translations: [] });
      
      expect(prisma.serviceCategory.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({
          name: 'Plumbing',
          slug: 'plumbing'
        })
      }));
      const createArgs = vi.mocked(prisma.serviceCategory.create).mock.calls[0]?.[0];
      expect(createArgs?.include?.subcategories).not.toHaveProperty('where');
      expect(createArgs?.include?._count?.select).toMatchObject({
        services: true,
        subcategories: true
      });
      expect(res.name).toBe('Plumbing');
    });

    it('appends -2 if category slug already exists', async () => {
      vi.mocked(prisma.serviceCategory.findUnique)
        .mockResolvedValueOnce({ id: 'existing' } as any) // first check finds it
        .mockResolvedValueOnce(null); // second check (-2) finds nothing
        
      prisma.serviceCategory.create = vi.fn().mockResolvedValue({ id: 'c2', name: 'Plumbing', slug: 'plumbing-2' } as any);

      const res = await catalogService.createCategory({ name: 'Plumbing', description: 'desc', iconUrl: 'url', seoTitle: '', seoDescription: '', translations: [] });
      
      expect(prisma.serviceCategory.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({
          slug: 'plumbing-2'
        })
      }));
      expect(res.slug).toBe('plumbing-2');
    });
  });

  describe('createService', () => {
    it('creates a service', async () => {
      vi.mocked(prisma.service.findUnique).mockResolvedValue(null);
      vi.mocked(prisma.serviceSubcategory.findUnique).mockResolvedValue({ id: 'sub1', categoryId: 'c1' } as any);
      
      prisma.service.create = vi.fn().mockResolvedValue({ id: 's1', name: 'Plumbing Fix', slug: 'plumbing-fix' } as any);

      const res = await catalogService.createService({
        name: 'Plumbing Fix',
        categoryId: 'c1',
        subcategoryId: 'sub1',
        startingPrice: 500,
        gstRate: 18,
        gstApplicable: true,
        sacCode: '9987',
        estimatedDurationMins: 60,
        description: 'desc',
      } as any);

      expect(prisma.service.create).toHaveBeenCalled();
      expect(res.name).toBe('Plumbing Fix');
    });
  });

  describe('updateService variant availability', () => {
    it('prevents removing variants referenced by maintenance plans', async () => {
      vi.mocked(prisma.service.findUnique).mockResolvedValueOnce({
        id: 'service-1',
        slug: 'service',
        code: 'SERVICE',
        name: 'Service',
        publishStartsAt: null,
        publishEndsAt: null,
        maintenanceEnabled: true,
        maintenanceIntervalsMonths: [3],
        guaranteeEnabled: false,
        guaranteeClaimWindowDays: 0,
        guaranteeIssueCategories: [],
        guaranteeResolutionTypes: [],
      } as any);
      prismaMockTx.serviceVariant.findMany.mockResolvedValueOnce([
        { id: 'variant-1' },
      ] as any);
      prismaMockTx.maintenancePlan.count.mockResolvedValueOnce(1);

      await expect(catalogService.updateService('service-1', { variants: [] }))
        .rejects.toMatchObject({ statusCode: 409 });

      expect(prismaMockTx.serviceVariant.deleteMany).not.toHaveBeenCalled();
      expect(prismaMockTx.maintenancePlan.count).toHaveBeenCalledWith({
        where: { variantId: { in: ['variant-1'] } },
      });
    });

    it('creates inherited variants without service-area assignments and preserves custom assignments', async () => {
      vi.mocked(prisma.service.findUnique)
        .mockResolvedValueOnce({
          id: 'service-1',
          slug: 'service',
          code: 'SERVICE',
          name: 'Service',
          publishStartsAt: null,
          publishEndsAt: null,
        } as any)
        .mockResolvedValueOnce({ id: 'service-1' } as any);
      vi.mocked(prisma.serviceArea.count).mockResolvedValue(1);
      prismaMockTx.serviceVariant.create.mockResolvedValue({} as any);
      prismaMockTx.serviceVariant.findMany.mockResolvedValueOnce([] as any);

      await catalogService.updateService('service-1', {
        variants: [
          { name: 'Inherited', price: 100, serviceAreaIds: [] },
          {
            name: 'Custom',
            price: 200,
            availabilityMode: 'CUSTOM',
            serviceAreaIds: ['area-1'],
          },
        ],
      });

      expect(prismaMockTx.serviceVariant.create).toHaveBeenNthCalledWith(
        1,
        expect.objectContaining({
          data: expect.objectContaining({
            availabilityMode: 'INHERITED',
            serviceAreaAssignments: undefined,
          }),
        }),
      );
      expect(prismaMockTx.serviceVariant.create).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({
          data: expect.objectContaining({
            availabilityMode: 'CUSTOM',
            serviceAreaAssignments: { create: [{ serviceAreaId: 'area-1' }] },
          }),
        }),
      );
    });
  });

  describe('bulkSetCatalogActiveStatus', () => {
    it('updates deduplicated service ids in one transaction', async () => {
      prismaMockTx.service.updateMany.mockResolvedValue({ count: 2 } as any);

      const result = await catalogService.bulkSetCatalogActiveStatus({
        entityType: 'services',
        ids: ['service-1', 'service-1', 'service-2'],
        isActive: false,
      });

      expect(prismaMockTx.service.updateMany).toHaveBeenCalledWith({
        where: { id: { in: ['service-1', 'service-2'] } },
        data: { isActive: false },
      });
      expect(result).toEqual({ updatedCount: 2 });
    });
  });

  describe('bulkUpdateCatalogAvailability', () => {
    it('materializes inherited parent locations before removing selected areas', async () => {
      prismaMockTx.service.count.mockResolvedValue(1);
      prismaMockTx.serviceArea.count.mockResolvedValue(1);
      prismaMockTx.service.findMany.mockResolvedValue([
        {
          id: 'service-1',
          availabilityMode: 'INHERITED',
          serviceAreaAssignments: [],
          subcategory: {
            availabilityMode: 'INHERITED',
            serviceAreaAssignments: [],
            category: {
              availabilityMode: 'CUSTOM',
              serviceAreaAssignments: [
                { serviceAreaId: 'area-remove' },
                { serviceAreaId: 'area-keep' },
              ],
            },
          },
        },
      ] as any);
      prismaMockTx.serviceAreaService.deleteMany.mockResolvedValue({ count: 0 } as any);

      const result = await catalogService.bulkUpdateCatalogAvailability({
        action: 'REMOVE_LOCATIONS',
        serviceIds: ['service-1'],
        serviceAreaIds: ['area-remove'],
      });

      expect(prismaMockTx.service.updateMany).toHaveBeenCalledWith({
        where: { id: { in: ['service-1'] } },
        data: { availabilityMode: 'CUSTOM' },
      });
      expect(prismaMockTx.serviceAreaService.createMany).toHaveBeenCalledWith({
        data: [{ serviceId: 'service-1', serviceAreaId: 'area-keep' }],
      });
      expect(result).toEqual({
        action: 'REMOVE_LOCATIONS',
        updatedCount: 1,
        removedAssignmentCount: 1,
      });
    });

    it('rejects materializing an unrestricted inherited service across too many active areas', async () => {
      prismaMockTx.service.count.mockResolvedValue(1);
      prismaMockTx.serviceArea.count.mockResolvedValue(1);
      prismaMockTx.service.findMany.mockResolvedValue([
        {
          id: 'service-1',
          availabilityMode: 'INHERITED',
          serviceAreaAssignments: [],
          subcategory: {
            availabilityMode: 'INHERITED',
            serviceAreaAssignments: [],
            category: {
              availabilityMode: 'INHERITED',
              serviceAreaAssignments: [],
            },
          },
        },
      ] as any);
      prismaMockTx.serviceArea.findMany.mockResolvedValue(
        Array.from({ length: 1001 }, (_, index) => ({ id: `area-${index}` })) as any,
      );

      await expect(
        catalogService.bulkUpdateCatalogAvailability({
          action: 'REMOVE_LOCATIONS',
          serviceIds: ['service-1'],
          serviceAreaIds: ['area-remove'],
        }),
      ).rejects.toBeInstanceOf(AppError);
      expect(prismaMockTx.service.updateMany).not.toHaveBeenCalled();
    });
  });
});
