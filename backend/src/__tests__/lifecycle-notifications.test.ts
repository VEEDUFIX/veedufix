import { beforeEach, describe, expect, it, vi } from "vitest";
import { BookingStatus } from "@prisma/client";

const mocks = vi.hoisted(() => ({
  bookingFindMany: vi.fn(),
  workerFindUnique: vi.fn(),
  deviceTokenFindMany: vi.fn(),
  redisSet: vi.fn(),
  redisExists: vi.fn(),
  redisEval: vi.fn(),
  sendPush: vi.fn(),
  loggerError: vi.fn()
}));

vi.mock("node-cron", () => ({ default: { schedule: vi.fn() } }));
vi.mock("../lib/prisma.js", () => ({
  prisma: {
    booking: { findMany: mocks.bookingFindMany },
    workerProfile: { findUnique: mocks.workerFindUnique },
    deviceToken: { findMany: mocks.deviceTokenFindMany }
  }
}));
vi.mock("../lib/redis.js", () => ({
  redis: {
    set: mocks.redisSet,
    exists: mocks.redisExists,
    eval: mocks.redisEval
  }
}));
vi.mock("../lib/fcm.js", () => ({ sendPushNotification: mocks.sendPush }));
vi.mock("../lib/logger.js", () => ({ logger: { error: mocks.loggerError } }));

import { processLifecycleNotifications } from "../modules/scheduler/lifecycle-notifications.js";

describe("lifecycle notifications", () => {
  const claims = new Map<string, string>();
  const sent = new Set<string>();
  let failWorkerPush = true;

  beforeEach(() => {
    vi.clearAllMocks();
    claims.clear();
    sent.clear();
    failWorkerPush = true;

    const booking = {
      id: "booking-1",
      customerId: "customer-1",
      workerId: "worker-profile-1",
      scheduledAt: new Date(Date.now() + 60 * 60 * 1000),
      address: { line1: "12 Main Street" },
      services: [{ serviceSubcategory: { name: "Plumbing" } }]
    };
    mocks.bookingFindMany.mockImplementation(async (query: { where: { status?: unknown } }) => {
      return query.where.status && typeof query.where.status === "object" && "in" in query.where.status
        ? [booking]
        : [];
    });
    mocks.workerFindUnique.mockResolvedValue({ userId: "worker-user-1" });
    mocks.deviceTokenFindMany.mockImplementation(async (query: { where: { userId: string } }) => [
      { token: query.where.userId === "customer-1" ? "customer-token" : "worker-token" }
    ]);
    mocks.redisSet.mockImplementation(async (key: string, value: string) => {
      if (claims.has(key)) return null;
      claims.set(key, value);
      return "OK";
    });
    mocks.redisExists.mockImplementation(async (key: string) => Number(sent.has(key)));
    mocks.redisEval.mockImplementation(async (_script: string, keyCount: number, ...args: string[]) => {
      const [claimKey, sentKey, claimId] = keyCount === 2
        ? args
        : [args[0], undefined, args[1]];
      if (claims.get(claimKey) !== claimId) return 0;
      claims.delete(claimKey);
      if (sentKey) sent.add(sentKey);
      return 1;
    });
    mocks.sendPush.mockImplementation(async ({ token }: { token: string }) => {
      if (token === "worker-token" && failWorkerPush) {
        failWorkerPush = false;
        return { success: false, error: "temporary FCM failure" };
      }
      return { success: true, messageId: `sent-${token}` };
    });
  });

  it("retries only failed devices and does not resend successful recipients", async () => {
    await processLifecycleNotifications();
    expect(mocks.sendPush.mock.calls.map(([payload]) => payload.token)).toEqual([
      "customer-token",
      "worker-token"
    ]);

    await processLifecycleNotifications();
    expect(mocks.sendPush.mock.calls.map(([payload]) => payload.token)).toEqual([
      "customer-token",
      "worker-token",
      "worker-token"
    ]);

    await processLifecycleNotifications();
    expect(mocks.sendPush).toHaveBeenCalledTimes(3);
    expect(mocks.loggerError).toHaveBeenCalledTimes(1);
  });
});
