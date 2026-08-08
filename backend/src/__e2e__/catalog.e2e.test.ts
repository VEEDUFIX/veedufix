import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

// ─── Mocks ────────────────────────────────────────────────────────────────────
vi.mock('../lib/prisma.js', () => ({
  prisma: {
    serviceCategory: {
      findMany: vi.fn(),
      findUnique: vi.fn(),
    },
    service: {
      findMany: vi.fn(),
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      count: vi.fn(),
    },
  }
}));

vi.mock('../lib/redis.js', () => ({
  redis: {
    get: vi.fn(),
    set: vi.fn(),
    del: vi.fn(),
    incr: vi.fn().mockResolvedValue(1),
    expire: vi.fn(),
  }
}));

vi.mock('express-rate-limit', () => ({
  default: () => (req: any, res: any, next: any) => next(),
  ipKeyGenerator: () => '127.0.0.1'
}));

vi.mock('../config/env.js', () => ({
  env: {
    PORT: 4000,
    NODE_ENV: 'test',
    JWT_ACCESS_SECRET: 'test-secret',
    JWT_REFRESH_SECRET: 'test-refresh-secret',
    JWT_ACCESS_TTL: '15m',
    JWT_REFRESH_TTL: '30d',
    REDIS_URL: 'redis://localhost:6379',
    APP_CORS_ORIGIN: 'http://localhost:3000',
    RAZORPAY_KEY_ID: 'test_key',
    RAZORPAY_KEY_SECRET: 'test_secret',
    RAZORPAY_WEBHOOK_SECRET: 'test_secret',
  }
}));

// ─── Imports ──────────────────────────────────────────────────────────────────
import { createApp } from '../app.js';
import { prisma } from '../lib/prisma.js';

const app = createApp();

describe('Catalog API (E2E)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /api/catalog/categories', () => {
    it('returns a list of categories', async () => {
      const mockCategories = [
        { id: 'cat1', name: 'Cleaning', isActive: true, subcategories: [] },
        { id: 'cat2', name: 'Plumbing', isActive: true, subcategories: [] }
      ];
      vi.mocked(prisma.serviceCategory.findMany).mockResolvedValue(mockCategories as any);

      const res = await request(app).get('/api/catalog/categories');
      
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('categories');
      expect(res.body.categories).toEqual(mockCategories);
      expect(prisma.serviceCategory.findMany).toHaveBeenCalled();
    });

    it('returns 500 if database fails', async () => {
      vi.mocked(prisma.serviceCategory.findMany).mockRejectedValue(new Error('DB Error'));

      const res = await request(app).get('/api/catalog/categories');
      
      expect(res.status).toBe(500);
    });
  });

  describe('GET /api/catalog/categories/:id', () => {
    it('returns a specific category', async () => {
      const mockCategory = { id: 'cat1', slug: 'cleaning', name: 'Cleaning', isActive: true };
      vi.mocked(prisma.serviceCategory.findUnique).mockResolvedValue(mockCategory as any);

      const res = await request(app).get('/api/catalog/categories/cleaning');
      
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('category');
      expect(res.body.category.id).toEqual('cat1');
      expect(prisma.serviceCategory.findUnique).toHaveBeenCalled();
    });

    it('returns 404 if category not found', async () => {
      vi.mocked(prisma.serviceCategory.findUnique).mockResolvedValue(null);

      const res = await request(app).get('/api/catalog/categories/cleaning');
      
      expect(res.status).toBe(404);
    });
  });

  describe('GET /api/catalog/services', () => {
    it('returns a list of services', async () => {
      const mockServices = [
        { id: 'srv1', name: 'House Cleaning', categoryId: 'cat1' },
        { id: 'srv2', name: 'Pipe Repair', categoryId: 'cat2' }
      ];
      vi.mocked(prisma.service.findMany).mockResolvedValue(mockServices as any);
      vi.mocked(prisma.service.count).mockResolvedValue(2);

      const res = await request(app).get('/api/catalog/services');
      
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('items');
      expect(res.body.items).toEqual(mockServices);
      expect(prisma.service.findMany).toHaveBeenCalled();
    });
    
    it('returns 500 if database fails', async () => {
      vi.mocked(prisma.service.findMany).mockRejectedValue(new Error('DB Error'));

      const res = await request(app).get('/api/catalog/services');
      
      expect(res.status).toBe(500);
    });
  });

  describe('GET /api/catalog/services/:id', () => {
    it('returns a specific service', async () => {
      const mockService = { id: 'srv1', slug: 'house-cleaning', name: 'House Cleaning', pricingRules: [], startingPrice: 100 };
      vi.mocked(prisma.service.findFirst).mockResolvedValue(mockService as any);

      const res = await request(app).get('/api/catalog/services/house-cleaning');
      
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('service');
      expect(res.body.service.id).toEqual('srv1');
      expect(prisma.service.findFirst).toHaveBeenCalled();
    });

    it('returns 404 if service not found', async () => {
      vi.mocked(prisma.service.findFirst).mockResolvedValue(null);

      const res = await request(app).get('/api/catalog/services/house-cleaning');
      
      expect(res.status).toBe(404);
    });
  });
});
