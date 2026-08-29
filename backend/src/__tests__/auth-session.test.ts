import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../lib/jwt.js', () => ({
  verifyAccessToken: vi.fn(),
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    authSession: {
      findFirst: vi.fn(),
    },
  },
}));

import { verifyAccessToken } from '../lib/jwt.js';
import { prisma } from '../lib/prisma.js';
import { authenticateAccessToken, hashToken } from '../lib/auth-session.js';
import { AppError } from '../lib/app-error.js';

describe('auth-session', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('hashToken creates a stable sha256 digest', () => {
    expect(hashToken('token-123')).toHaveLength(64);
    expect(hashToken('token-123')).toBe(hashToken('token-123'));
  });

  it('rejects an access token when the stored session is missing', async () => {
    vi.mocked(verifyAccessToken).mockReturnValue({
      sub: 'user-1',
      role: 'CUSTOMER',
      sessionId: 'sess-1',
    } as never);
    vi.mocked(prisma.authSession.findFirst).mockResolvedValue(null as never);

    await expect(authenticateAccessToken('token-123')).rejects.toSatisfy((err: unknown) => {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).statusCode).toBe(401);
      return true;
    });
  });

  it('accepts a token only when the hashed token matches the active session', async () => {
    vi.mocked(verifyAccessToken).mockReturnValue({
      sub: 'user-1',
      role: 'CUSTOMER',
      sessionId: 'sess-1',
    } as never);
    vi.mocked(prisma.authSession.findFirst).mockResolvedValue({
      id: 'sess-1',
      user: { id: 'user-1', role: 'CUSTOMER' },
    } as never);

    const payload = await authenticateAccessToken('token-123');

    expect(payload.sub).toBe('user-1');
    expect(prisma.authSession.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({
        id: 'sess-1',
        userId: 'user-1',
        accessToken: hashToken('token-123'),
      }),
    }));
  });
});
