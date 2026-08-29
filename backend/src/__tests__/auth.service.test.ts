/**
 * Unit tests for auth.service — OTP request + verification + refresh flow.
 *
 * All external dependencies are mocked so these run in isolation with no
 * real DB, Redis, or network calls.
 *
 * Path note: test file is at src/__tests__/, so src/ is one level up (../).
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

// ─── Mock all external modules BEFORE importing the module under test ─────────

vi.mock('bcryptjs', () => ({
  default: {
    hash: vi.fn(),
    compare: vi.fn(),
  },
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    user: { upsert: vi.fn() },
    refreshToken: { create: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
    authSession: { create: vi.fn(), updateMany: vi.fn() },
  },
}));

vi.mock('../lib/redis.js', () => ({
  redis: {
    set: vi.fn(),
    get: vi.fn(),
    del: vi.fn(),
    incr: vi.fn(),
    expire: vi.fn(),
  },
}));

vi.mock('../lib/jwt.js', () => ({
  signAccessToken: vi.fn(() => 'mock-access-token'),
  signRefreshToken: vi.fn(() => 'mock-refresh-token'),
  verifyRefreshToken: vi.fn(),
}));

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
}));

vi.mock('../lib/firebase.js', () => ({
  verifyGoogleIdToken: vi.fn(),
}));

vi.mock('../config/env.js', () => ({
  env: {
    RAZORPAY_KEY_ID: 'rzp_test_key',
    RAZORPAY_KEY_SECRET: 'test_secret',
    JWT_ACCESS_TTL: '15m',
    JWT_REFRESH_TTL: '30d',
    OTP_TTL_SECONDS: '300',
  },
}));

// ─── Import AFTER mocks are registered ───────────────────────────────────────

import bcrypt from 'bcryptjs';
import { prisma } from '../lib/prisma.js';
import { redis } from '../lib/redis.js';
import { requestOtp, verifyOtp, refreshSession } from '../modules/auth/auth.service.js';
import { AppError } from '../lib/app-error.js';

// ─── Shared test data ─────────────────────────────────────────────────────────

const mockUser = {
  id: 'user-001',
  role: 'CUSTOMER' as const,
  name: 'Test User',
  email: null,
  phone: '+919876543210',
  avatarUrl: null,
  createdAt: new Date(),
};

// ─── requestOtp ───────────────────────────────────────────────────────────────

describe('requestOtp', () => {
  beforeEach(() => vi.clearAllMocks());

  it('hashes a 6-digit OTP and stores it in Redis with a TTL', async () => {
    vi.mocked(bcrypt.hash).mockResolvedValue('hashed-otp' as never);
    vi.mocked(redis.set).mockResolvedValue('OK');

    await requestOtp('PHONE', '+919876543210');

    expect(bcrypt.hash).toHaveBeenCalledOnce();
    const [otpArg] = vi.mocked(bcrypt.hash).mock.calls[0];
    expect(String(otpArg)).toMatch(/^\d{6}$/);

    expect(redis.set).toHaveBeenCalledOnce();
    const [key] = vi.mocked(redis.set).mock.calls[0];
    expect(key as string).toContain('PHONE');
  });

  it('normalises phone by stripping non-digit characters', async () => {
    vi.mocked(bcrypt.hash).mockResolvedValue('hashed-otp' as never);
    vi.mocked(redis.set).mockResolvedValue('OK');

    await requestOtp('PHONE', '  +91-98765-43210  ');

    const [key] = vi.mocked(redis.set).mock.calls[0];
    // key should not contain spaces or hyphens
    expect(key as string).not.toMatch(/[\s-]/);
  });
});

// ─── verifyOtp ────────────────────────────────────────────────────────────────

describe('verifyOtp', () => {
  beforeEach(() => vi.clearAllMocks());

  it('throws AppError 410 when OTP has expired (key missing from Redis)', async () => {
    vi.mocked(redis.get).mockResolvedValue(null);

    await expect(
      verifyOtp({ channel: 'PHONE', identifier: '+919876543210', otp: '123456' })
    ).rejects.toSatisfy((err: unknown) => {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).statusCode).toBe(410);
      expect((err as AppError).message).toMatch(/expired/i);
      return true;
    });
  });

  it('throws AppError 400 when OTP value is wrong', async () => {
    // First call: lock check (null = not locked)
    // Second call: hash fetch (returns hashed value)
    vi.mocked(redis.get)
      .mockResolvedValueOnce(null)       // lock key → not locked
      .mockResolvedValueOnce('hashed-otp'); // otp key → hash present
    vi.mocked(redis.incr).mockResolvedValue(1); // 1st attempt → 4 remaining
    vi.mocked(redis.expire).mockResolvedValue(1);
    vi.mocked(bcrypt.compare).mockResolvedValue(false as never);

    await expect(
      verifyOtp({ channel: 'PHONE', identifier: '+919876543210', otp: '000000' })
    ).rejects.toSatisfy((err: unknown) => {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).statusCode).toBe(400);
      expect((err as AppError).message).toMatch(/invalid otp/i);
      return true;
    });
  });

  it('returns access + refresh tokens and user on a correct OTP', async () => {
    vi.mocked(redis.get)
      .mockResolvedValueOnce(null)        // lock key → not locked
      .mockResolvedValueOnce('hashed-otp'); // otp key → hash present
    vi.mocked(bcrypt.compare).mockResolvedValue(true as never);
    vi.mocked(redis.del).mockResolvedValue(1);
    vi.mocked(prisma.user.upsert).mockResolvedValue(mockUser as never);
    vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as never);
    vi.mocked(prisma.authSession.create).mockResolvedValue({} as never);

    const result = await verifyOtp({
      channel: 'PHONE',
      identifier: '+919876543210',
      otp: '123456',
    });

    expect(result.accessToken).toBe('mock-access-token');
    expect(result.refreshToken).toBe('mock-refresh-token');
    expect(result.user.id).toBe('user-001');
    expect(result.user.role).toBe('CUSTOMER');
  });

  it('deletes the OTP key from Redis after success (prevents replay)', async () => {
    vi.mocked(redis.get)
      .mockResolvedValueOnce(null)        // lock key → not locked
      .mockResolvedValueOnce('hashed-otp'); // otp key → hash present
    vi.mocked(bcrypt.compare).mockResolvedValue(true as never);
    vi.mocked(redis.del).mockResolvedValue(1);
    vi.mocked(prisma.user.upsert).mockResolvedValue(mockUser as never);
    vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as never);
    vi.mocked(prisma.authSession.create).mockResolvedValue({} as never);

    await verifyOtp({ channel: 'PHONE', identifier: '+919876543210', otp: '123456' });

    // del is called for: otp key + attempts key (2 calls on success)
    expect(redis.del).toHaveBeenCalledTimes(2);
  });
});

// ─── refreshSession ───────────────────────────────────────────────────────────

describe('refreshSession', () => {
  beforeEach(() => vi.clearAllMocks());

  it('throws AppError 401 when token is revoked', async () => {
    const { verifyRefreshToken } = await import('../lib/jwt.js');
    vi.mocked(verifyRefreshToken).mockReturnValue({
      sub: 'user-001', role: 'CUSTOMER', sessionId: 'sess-1',
    } as never);
    vi.mocked(prisma.refreshToken.findUnique).mockResolvedValue({
      id: 'rt-001', revokedAt: new Date(), userId: 'user-001', user: mockUser,
    } as never);

    await expect(refreshSession('some-token')).rejects.toSatisfy((err: unknown) => {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).statusCode).toBe(401);
      return true;
    });
  });

  it('throws AppError 401 when token does not exist in DB', async () => {
    const { verifyRefreshToken } = await import('../lib/jwt.js');
    vi.mocked(verifyRefreshToken).mockReturnValue({
      sub: 'user-001', role: 'CUSTOMER', sessionId: 'sess-1',
    } as never);
    vi.mocked(prisma.refreshToken.findUnique).mockResolvedValue(null);

    await expect(refreshSession('ghost-token')).rejects.toSatisfy((err: unknown) => {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).statusCode).toBe(401);
      return true;
    });
  });

  it('returns a new token pair and revokes the old token on success', async () => {
    const { verifyRefreshToken } = await import('../lib/jwt.js');
    vi.mocked(verifyRefreshToken).mockReturnValue({
      sub: 'user-001', role: 'CUSTOMER', sessionId: 'sess-1',
    } as never);
    vi.mocked(prisma.refreshToken.findUnique).mockResolvedValue({
      id: 'rt-001', revokedAt: null, userId: 'user-001', user: mockUser,
    } as never);
    vi.mocked(prisma.refreshToken.update).mockResolvedValue({} as never);
    vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as never);
    vi.mocked(prisma.authSession.updateMany).mockResolvedValue({ count: 1 } as never);

    const result = await refreshSession('valid-token');

    expect(result.accessToken).toBe('mock-access-token');
    expect(result.refreshToken).toBe('mock-refresh-token');
    expect(result.user.id).toBe('user-001');

    // Old token must be marked as revoked
    expect(prisma.refreshToken.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ revokedAt: expect.any(Date) }),
      })
    );
  });
});
