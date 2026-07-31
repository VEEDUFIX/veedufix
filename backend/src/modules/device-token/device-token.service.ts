import { prisma } from "../../lib/prisma.js";

export type DeviceTokenInput = {
  token: string;
  platform?: string | null;
  deviceId?: string | null;
};

export async function getTokensForUser(userId: string): Promise<string[]> {
  const tokens = await prisma.deviceToken.findMany({
    where: { userId },
    orderBy: [{ lastSeenAt: "desc" }, { updatedAt: "desc" }],
    select: { token: true }
  });

  return tokens.map((record) => record.token);
}

export async function upsertDeviceToken(userId: string, input: DeviceTokenInput): Promise<void> {
  const now = new Date();

  await prisma.deviceToken.upsert({
    where: { token: input.token },
    create: {
      userId,
      token: input.token,
      platform: input.platform ?? null,
      deviceId: input.deviceId ?? null,
      lastSeenAt: now
    },
    update: {
      userId,
      platform: input.platform ?? null,
      deviceId: input.deviceId ?? null,
      lastSeenAt: now
    }
  });
}

export async function revokeDeviceToken(userId: string, token: string): Promise<number> {
  const result = await prisma.deviceToken.deleteMany({
    where: {
      userId,
      token
    }
  });

  return result.count;
}
