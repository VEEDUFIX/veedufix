import { Prisma, VerificationStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { isWorkerEligible } from "../worker-onboarding/worker-onboarding.service.js";

type WorkerPoolQuery = {
  page?: number;
  limit?: number;
  cityId?: string;
  categoryId?: string;
  onlyAvailable?: boolean;
};

type WorkerPoolItem = Prisma.WorkerProfileGetPayload<{
  include: {
    user: {
      select: {
        id: true;
        name: true;
        email: true;
        phone: true;
        avatarUrl: true;
      };
    };
    cityRelation: true;
    skills: {
      include: {
        category: true;
      };
    };
  };
}>;

function normalizeWorkerPoolItem(worker: WorkerPoolItem) {
  return {
    id: worker.id,
    userId: worker.userId,
    fullName: worker.fullName,
    displayName: worker.displayName,
    cityId: worker.cityId,
    city: worker.city,
    cityRelation: worker.cityRelation,
    averageRating: worker.averageRating,
    completedJobsCount: worker.completedJobsCount,
    experienceYears: worker.experienceYears,
    serviceRadiusKm: worker.serviceRadiusKm,
    basePrice: worker.basePrice,
    commissionRate: worker.commissionRate,
    onboardingStatus: worker.onboardingStatus,
    verificationStatus: worker.verificationStatus,
    isAvailable: worker.isAvailable,
    isOnline: worker.isOnline,
    submittedAt: worker.submittedAt,
    reviewedAt: worker.reviewedAt,
    user: worker.user,
    skills: worker.skills.map((skill) => ({
      id: skill.id,
      categoryId: skill.categoryId,
      verifiedByAdmin: skill.verifiedByAdmin,
      certificationDocUrl: skill.certificationDocUrl,
      yearsExperience: skill.yearsExperience,
      isPrimary: skill.isPrimary,
      category: {
        id: skill.category.id,
        name: skill.category.name,
        slug: skill.category.slug,
        iconUrl: skill.category.iconUrl,
        description: skill.category.description
      }
    }))
  };
}

export async function listEligibleWorkers(query: WorkerPoolQuery = {}) {
  const page = query.page ?? 1;
  const limit = query.limit ?? 20;
  const skip = (page - 1) * limit;

  const where: Prisma.WorkerProfileWhereInput = {
    onboardingStatus: "approved",
    verificationStatus: VerificationStatus.VERIFIED,
    ...(query.cityId ? { cityId: query.cityId } : {}),
    ...(query.onlyAvailable ? { isAvailable: true } : {}),
    ...(query.categoryId
      ? {
          skills: {
            some: {
              categoryId: query.categoryId
            }
          }
        }
      : {})
  };

  const [total, workers] = await prisma.$transaction([
    prisma.workerProfile.count({ where }),
    prisma.workerProfile.findMany({
      where,
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            avatarUrl: true
          }
        },
        cityRelation: true,
        skills: {
          include: {
            category: true
          }
        }
      },
      orderBy: [{ averageRating: "desc" }, { completedJobsCount: "desc" }, { createdAt: "asc" }],
      skip,
      take: limit
    })
  ]);

  const checked = await Promise.all(
    workers.map(async (worker) => {
      const eligible = await isWorkerEligible(worker.userId);
      return eligible ? worker : null;
    })
  );

  const items = checked.filter((worker): worker is WorkerPoolItem => worker !== null);

  return {
    items: items.map(normalizeWorkerPoolItem),
    page,
    limit,
    total,
    totalPages: Math.max(1, Math.ceil(total / limit))
  };
}

