import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

// ─── Mocks ────────────────────────────────────────────────────────────────────
vi.mock('../lib/prisma.js', () => ({
  prisma: {
    user: {
      findUnique: vi.fn(),
      upsert: vi.fn(),
      create: vi.fn(),
    },
    userSession: {
      create: vi.fn(),
    },
    authSession: {
      create: vi.fn(),
    },
    refreshToken: {
      create: vi.fn(),
    }
  }
}));

vi.mock('../lib/redis.js', async () => {
  const bcrypt = await import('bcryptjs');
  const validHash = bcrypt.hashSync('123456', 10);
  return {
    redis: {
      set: vi.fn(),
      get: vi.fn((key: any) => {
        if (String(key).includes('locked')) return Promise.resolve(null);
        return Promise.resolve(validHash);
      }),
      del: vi.fn(),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn(),
    }
  };
});

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
import { redis } from '../lib/redis.js';

const app = createApp();

describe('Auth API (E2E)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/auth/otp/request', () => {
    it('returns 400 for invalid payload', async () => {
      const res = await request(app)
        .post('/api/auth/otp/request')
        .send({ identifier: 'invalid' }); // Missing channel
      
      expect(res.status).toBe(400);
      expect(res.body.message).toBe('Validation failed');
    });

    it('returns 200 and sends OTP for valid identifier', async () => {
      vi.mocked(redis.set).mockResolvedValue('OK');

      const res = await request(app)
        .post('/api/auth/otp/request')
        .send({ channel: 'PHONE', identifier: '+919876543210' });
      
      expect(res.status).toBe(200);
      expect(res.body.message).toBe('OTP requested');
      expect(redis.set).toHaveBeenCalled();
    });
  });

  describe('POST /api/auth/otp/verify', () => {
    it('returns 400 for invalid OTP format', async () => {
      const res = await request(app)
        .post('/api/auth/otp/verify')
        .send({ channel: 'PHONE', identifier: '+919876543210', otp: '123' }); // Too short
      
      expect(res.status).toBe(400);
      expect(res.body.message).toBe('Validation failed');
    });

    it('returns 400 for incorrect OTP', async () => {
      vi.mocked(redis.get).mockImplementation(async (key: any) => {
        if (String(key).includes('locked')) return null;
        // Use a valid but incorrect bcrypt hash
        return '$2a$10$1Y5O7w.pXU0Y1O9K2/l3.O3n3oU9u7yG1wM7X2z8qW6I1Y2Z3U4rG'; 
      });

      const res = await request(app)
        .post('/api/auth/otp/verify')
        .send({ channel: 'PHONE', identifier: '+919876543210', otp: '123456' });
      
      expect(res.status).toBe(400);
      expect(res.body.message).toContain('Invalid OTP');
    });

    it('returns 200 and issues tokens for valid OTP', async () => {
      const bcrypt = await import('bcryptjs');
      const validHash2 = bcrypt.hashSync('123456', 10);
      
      vi.mocked(redis.get).mockImplementation(async (key: any) => {
        if (String(key).includes('locked')) return null;
        return validHash2;
      });
      vi.mocked(prisma.user.upsert).mockResolvedValue({
        id: 'user1', phone: '+919876543210', role: 'CUSTOMER', isActive: true, createdAt: new Date(0)
      } as any);
      vi.mocked(prisma.authSession.create).mockResolvedValue({ id: 'session1' } as any);

      const res = await request(app)
        .post('/api/auth/otp/verify')
        .send({ channel: 'PHONE', identifier: '+919876543210', otp: '123456', name: 'Test User' });
      
      expect(res.status).toBe(200);
      expect(res.body.user.id).toBe('user1');
      expect(res.body).toHaveProperty('accessToken');
      expect(res.body).toHaveProperty('refreshToken');
    });
  });
});
