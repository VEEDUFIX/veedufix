import { beforeEach, describe, expect, it, vi } from "vitest";

const { prismaMock, txMock } = vi.hoisted(() => {
  const txMock = {
    $queryRaw: vi.fn(),
    workerProfile: { findUnique: vi.fn(), update: vi.fn() },
    workerProfileServiceArea: { count: vi.fn() },
    workerSkill: { updateMany: vi.fn() }
  };
  return {
    txMock,
    prismaMock: {
      workerProfile: { findUnique: vi.fn(), update: vi.fn() },
      workerProfileServiceArea: { count: vi.fn() },
      workerSkill: { updateMany: vi.fn() },
      $transaction: vi.fn(async (callback: (tx: typeof txMock) => unknown) => callback(txMock))
    }
  };
});

vi.mock("../lib/prisma.js", () => ({ prisma: prismaMock }));

import { prisma } from "../lib/prisma.js";
import {
  approveWorker,
  reinstateWorker,
  WorkerStatusConflictError
} from "../modules/worker-onboarding/worker-onboarding.service.js";

describe("Partner approval service-area requirements", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    txMock.workerProfile.findUnique.mockResolvedValue({
      userId: "partner-user-1",
      onboardingStatus: "suspended"
    });
    txMock.workerProfileServiceArea.count.mockResolvedValue(0);
  });

  it("does not approve a Partner without an active service-area assignment", async () => {
    await expect(approveWorker("worker-profile-1", "admin-1")).rejects.toBeInstanceOf(
      WorkerStatusConflictError
    );

    expect(txMock.$queryRaw).toHaveBeenCalledOnce();
    expect(txMock.workerProfileServiceArea.count).toHaveBeenCalledWith({
      where: {
        workerProfileId: "worker-profile-1",
        serviceArea: { isActive: true, city: { isActive: true } }
      }
    });
    expect(prisma.$transaction).toHaveBeenCalledOnce();
    expect(txMock.$queryRaw.mock.invocationCallOrder[0]).toBeLessThan(
      txMock.workerProfileServiceArea.count.mock.invocationCallOrder[0]
    );
  });

  it("does not reinstate a Partner without an active service-area assignment", async () => {
    await expect(
      reinstateWorker("worker-profile-1", "admin-1", "reviewed")
    ).rejects.toBeInstanceOf(WorkerStatusConflictError);

    expect(txMock.$queryRaw).toHaveBeenCalledOnce();
    expect(txMock.workerProfileServiceArea.count).toHaveBeenCalledOnce();
    expect(txMock.workerProfile.update).not.toHaveBeenCalled();
    expect(txMock.$queryRaw.mock.invocationCallOrder[0]).toBeLessThan(
      txMock.workerProfileServiceArea.count.mock.invocationCallOrder[0]
    );
  });
});
