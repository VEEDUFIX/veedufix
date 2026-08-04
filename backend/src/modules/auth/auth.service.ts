import bcrypt from "bcryptjs";
import { createHash, randomInt } from "crypto";
import { env } from "../../config/env.js";
import { prisma } from "../../lib/prisma.js";
import { redis } from "../../lib/redis.js";
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  type TokenPayload
} from "../../lib/jwt.js";
import { logger } from "../../lib/logger.js";
import { verifyGoogleIdToken } from "../../lib/firebase.js";

type LoginChannel = "PHONE" | "EMAIL";
type LoginRole = "CUSTOMER" | "WORKER" | "ADMIN";
type SessionProvider = "PHONE" | "EMAIL" | "GOOGLE";

type AuthResult = {
  user: {
    id: string;
    role: LoginRole;
    name: string;
    email: string | null;
    phone: string | null;
    avatarUrl: string | null;
  };
  accessToken: string;
  refreshToken: string;
};

function normalizeIdentifier(identifier: string, channel: LoginChannel): string {
  const trimmed = identifier.trim();
  if (channel === "PHONE") {
    return trimmed.replace(/[^\d+]/g, "");
  }
  return trimmed.toLowerCase();
}

function otpKey(channel: LoginChannel, identifier: string): string {
  return `otp:${channel}:${normalizeIdentifier(identifier, channel)}`;
}

function refreshTokenHash(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

async function upsertAuthSession(
  userId: string,
  provider: SessionProvider,
  providerId: string,
  accessToken: string,
  refreshToken: string
): Promise<string> {
  const session = await prisma.authSession.upsert({
    where: { providerId },
    create: {
      userId,
      provider,
      providerId,
      accessToken,
      refreshToken
    },
    update: {
      userId,
      provider,
      accessToken,
      refreshToken
    }
  });

  return session.id;
}

async function persistRefreshToken(userId: string, token: string, expiresInSeconds: number): Promise<void> {
  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash: refreshTokenHash(token),
      expiresAt: new Date(Date.now() + expiresInSeconds * 1000)
    }
  });
}

function extractExpirySeconds(ttl: string): number {
  const match = ttl.match(/^(\d+)([smhd])$/i);
  if (!match) {
    return 60 * 60 * 24 * 30;
  }

  const value = Number(match[1]);
  const unit = match[2].toLowerCase();
  const multiplier = unit === "s" ? 1 : unit === "m" ? 60 : unit === "h" ? 3600 : 86400;
  return value * multiplier;
}

export async function requestOtp(
  channel: LoginChannel,
  identifier: string
): Promise<{ expiresInSeconds: number; debugOtp?: string }> {
  const normalized = normalizeIdentifier(identifier, channel);
  const otp = String(randomInt(100000, 999999));
  const hash = await bcrypt.hash(otp, 10);
  const key = otpKey(channel, normalized);

  await redis.set(key, hash, "EX", 300);

  if (env.NODE_ENV !== "production") {
    logger.info({ channel, identifier: normalized, otp }, "Development OTP issued");
  }

  return {
    expiresInSeconds: 300,
    ...(env.NODE_ENV !== "production" ? { debugOtp: otp } : {})
  };
}

export async function verifyOtp(input: {
  channel: LoginChannel;
  identifier: string;
  otp: string;
  name?: string;
}): Promise<AuthResult> {
  const normalized = normalizeIdentifier(input.identifier, input.channel);
  const key = otpKey(input.channel, normalized);
  const hash = await redis.get(key);

  if (!hash) {
    throw new Error("OTP expired or missing");
  }

  const verified = await bcrypt.compare(input.otp, hash);
  if (!verified) {
    throw new Error("Invalid OTP");
  }

  await redis.del(key);

  const baseData =
    input.channel === "EMAIL"
      ? { email: normalized, phone: null }
      : { email: null, phone: normalized };

  const user = await prisma.user.upsert({
    where:
      input.channel === "EMAIL"
        ? { email: normalized }
        : { phone: normalized },
    update: {
      // Role is intentionally NOT updated here — existing role is preserved.
      name: input.name ?? undefined,
      ...(input.channel === "EMAIL" ? { emailVerifiedAt: new Date() } : { phoneVerifiedAt: new Date() })
    },
    create: {
      role: "CUSTOMER",
      name: input.name ?? "New User",
      ...baseData,
      ...(input.channel === "EMAIL" ? { emailVerifiedAt: new Date() } : { phoneVerifiedAt: new Date() })
    }
  });

  const sessionId = await createSession(user.id, user.role);
  const accessToken = signAccessToken({ sub: user.id, role: user.role, sessionId });
  const refreshToken = signRefreshToken({ sub: user.id, role: user.role, sessionId });
  await persistRefreshToken(user.id, refreshToken, extractExpirySeconds(process.env.JWT_REFRESH_TTL ?? "30d"));
  await upsertAuthSession(
    user.id,
    input.channel,
    `${input.channel.toLowerCase()}:${normalized}`,
    accessToken,
    refreshToken
  );

  return {
    user: {
      id: user.id,
      role: user.role,
      name: user.name,
      email: user.email,
      phone: user.phone,
      avatarUrl: user.avatarUrl
    },
    accessToken,
    refreshToken
  };
}

async function createSession(userId: string, role: LoginRole): Promise<string> {
  return `sess_${userId}_${role}_${Date.now()}`;
}

export async function refreshSession(refreshToken: string): Promise<AuthResult> {
  const payload = verifyRefreshToken(refreshToken) as TokenPayload;
  const stored = await prisma.refreshToken.findUnique({
    where: { tokenHash: refreshTokenHash(refreshToken) },
    include: { user: true }
  });

  if (!stored || stored.revokedAt) {
    throw new Error("Refresh token revoked");
  }

  const sessionId = payload.sessionId;
  const accessToken = signAccessToken({ sub: stored.userId, role: stored.user.role, sessionId });
  const nextRefreshToken = signRefreshToken({ sub: stored.userId, role: stored.user.role, sessionId });

  await prisma.refreshToken.update({
    where: { id: stored.id },
    data: { revokedAt: new Date() }
  });
  await persistRefreshToken(stored.userId, nextRefreshToken, extractExpirySeconds(process.env.JWT_REFRESH_TTL ?? "30d"));
  await prisma.authSession.updateMany({
    where: { refreshToken },
    data: {
      accessToken,
      refreshToken: nextRefreshToken
    }
  });

  return {
    user: {
      id: stored.user.id,
      role: stored.user.role,
      name: stored.user.name,
      email: stored.user.email,
      phone: stored.user.phone,
      avatarUrl: stored.user.avatarUrl
    },
    accessToken,
    refreshToken: nextRefreshToken
  };
}

export async function signInWithGoogle(input: {
  idToken: string;
}): Promise<AuthResult> {
  const googleClaims = await verifyGoogleIdToken(input.idToken);
  const email =
    googleClaims.email?.toLowerCase() ??
    `google-${googleClaims.sub}@veedufix.local`;
  const name = googleClaims.name ?? "Google User";
  const avatarUrl = googleClaims.picture ?? null;
  const providerId = `google:${googleClaims.sub}`;

  const user = await prisma.user.upsert({
    where: { email },
    update: {
      // Role is intentionally NOT updated here — existing role is preserved.
      name,
      avatarUrl,
      emailVerifiedAt: new Date()
    },
    create: {
      role: "CUSTOMER",
      name,
      email,
      avatarUrl,
      emailVerifiedAt: new Date()
    }
  });

  const sessionId = await createSession(user.id, user.role);
  const accessToken = signAccessToken({ sub: user.id, role: user.role, sessionId });
  const refreshToken = signRefreshToken({ sub: user.id, role: user.role, sessionId });
  await persistRefreshToken(user.id, refreshToken, extractExpirySeconds(process.env.JWT_REFRESH_TTL ?? "30d"));
  await upsertAuthSession(user.id, "GOOGLE", providerId, accessToken, refreshToken);

  return {
    user: {
      id: user.id,
      role: user.role,
      name: user.name,
      email: user.email,
      phone: user.phone,
      avatarUrl: user.avatarUrl
    },
    accessToken,
    refreshToken
  };
}

export async function signOut(refreshToken: string): Promise<void> {
  await prisma.refreshToken.updateMany({
    where: { tokenHash: refreshTokenHash(refreshToken) },
    data: { revokedAt: new Date() }
  });
  await prisma.authSession.updateMany({
    where: { refreshToken },
    data: {
      accessToken: null,
      refreshToken: null
    }
  });
}

export type AuthSessionSummary = {
  id: string;
  provider: string;
  providerId: string;
  createdAt: Date;
  updatedAt: Date;
  isCurrent: boolean;
  isActive: boolean;
};

export async function listAuthSessions(userId: string, currentSessionId: string): Promise<AuthSessionSummary[]> {
  const sessions = await prisma.authSession.findMany({
    where: { userId },
    orderBy: { updatedAt: "desc" },
    select: {
      id: true,
      provider: true,
      providerId: true,
      accessToken: true,
      refreshToken: true,
      createdAt: true,
      updatedAt: true
    }
  });

  return sessions.map((session) => ({
    id: session.id,
    provider: session.provider,
    providerId: session.providerId,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    isCurrent: session.id === currentSessionId,
    isActive: Boolean(session.accessToken || session.refreshToken)
  }));
}

export async function revokeAuthSession(userId: string, sessionId: string): Promise<void> {
  await prisma.authSession.updateMany({
    where: { id: sessionId, userId },
    data: { accessToken: null, refreshToken: null }
  });
}

export async function revokeAllAuthSessions(userId: string, currentSessionId?: string): Promise<void> {
  await prisma.authSession.updateMany({
    where: {
      userId,
      ...(currentSessionId ? { id: { not: currentSessionId } } : {})
    },
    data: { accessToken: null, refreshToken: null }
  });

  await prisma.refreshToken.updateMany({
    where: { userId },
    data: { revokedAt: new Date() }
  });
}
