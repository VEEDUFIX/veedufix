import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    serviceCategory: { findMany: vi.fn(), findUnique: vi.fn(), create: vi.fn(), count: vi.fn() },
    serviceSubcategory: { findFirst: vi.fn(), create: vi.fn(), count: vi.fn(), findUnique: vi.fn() },
    service: { findFirst: vi.fn(), create: vi.fn(), count: vi.fn(), findMany: vi.fn(), findUnique: vi.fn() },
    $transaction: vi.fn((cb) => cb(prismaMockTx)),
  },
}));

const prismaMockTx = {
  serviceCategory: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  serviceSubcategory: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  service: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
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
      vi.mocked(prisma.serviceCategory.findUnique).mockResolvedValue(mockCategory as any);

      const category = await catalogService.resolveCategoryBySlug('home-repair');
      expect(category.name).toBe('Home Repair');
    });

    it('returns null if not found', async () => {
      vi.mocked(prisma.serviceCategory.findUnique).mockResolvedValue(null);
      const res = await catalogService.resolveCategoryBySlug('invalid');
      expect(res).toBeNull();
    });
  });

  describe('searchCatalog', () => {
    it('returns paginated search results', async () => {
      vi.mocked(prisma.service.count).mockResolvedValue(1);
      vi.mocked(prisma.service.findMany).mockResolvedValue([{ name: 'AC Cleaning', slug: 'ac-cleaning', isActive: true, translations: [], pricingRules: [] }] as any);

      const results = await catalogService.searchCatalog({ q: 'AC', page: 1, pageSize: 10 });
      expect(results.total).toBe(1);
      expect(results.items[0].name).toBe('AC Cleaning');
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
});
