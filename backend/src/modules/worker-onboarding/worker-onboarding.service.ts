import { Prisma, VerificationStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { uploadBufferToCloudinary } from "../../lib/cloudinary.js";

export class IncompleteProfileError extends Error {
  missingFields: string[];

  constructor(missingFields: string[]) {
    super("Worker profile is incomplete");
    this.name = "IncompleteProfileError";
    this.missingFields = missingFields;
  }
}

export class WorkerProfileNotFoundError extends Error {
  constructor(message = "Worker profile not found") {
    super(message);
    this.name = "WorkerProfileNotFoundError";
  }
}

export class WorkerStatusConflictError extends Error {
  constructor(message = "Worker profile is not in the expected status") {
    super(message);
    this.name = "WorkerStatusConflictError";
  }
}

type ProfileDetails = {
  fullName?: string;
  dateOfBirth?: Date | string;
  addressLine1?: string;
  city?: string;
  pincode?: string;
  bankAccountNumber?: string;
  bankIfsc?: string;
  upiId?: string;
  aadhaarNumber?: string;
};

type PendingReviewFilters = {
  page?: number;
  limit?: number;
  city?: string;
  categoryId?: string;
};

type WorkerDirectoryFilters = {
  page?: number;
  limit?: number;
  city?: string;
  categoryId?: string;
  status?: string;
};

type WorkerSkillWithCategory = Prisma.WorkerSkillGetPayload<{
  include: {
    category: true;
  };
}>;

type WorkerProfileWithRelations = Prisma.WorkerProfileGetPayload<{
  include: {
    user: {
      select: {
        id: true;
        name: true;
        email: true;
        phone: true;
        role: true;
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

type MinimalWorkerProfile = Prisma.WorkerProfileGetPayload<{
  include: {
    skills: {
      include: {
        category: true;
      };
    };
  };
}>;

type WorkerDirectoryProfile = Prisma.WorkerProfileGetPayload<{
  include: {
    user: {
      select: {
        id: true;
        name: true;
        email: true;
        phone: true;
        role: true;
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

type WorkerRatingRecord = Prisma.ReviewGetPayload<{
  include: {
    booking: {
      select: {
        code: true;
        customer: {
          select: {
            name: true;
          };
        };
      };
    };
    reviewer: {
      select: {
        id: true;
        name: true;
        avatarUrl: true;
      };
    };
  };
}>;

function roundToTwo(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function maskAadhaarNumber(value: string | null | undefined): string | null {
  if (!value) {
    return null;
  }

  const digits = value.replace(/\D/g, "");
  const last4 = digits.slice(-4).padStart(4, "0");
  return `XXXX-XXXX-${last4}`;
}

function toDate(value: Date | string | undefined): Date | undefined {
  if (!value) {
    return undefined;
  }

  return value instanceof Date ? value : new Date(value);
}

function normalizeProfile(profile: WorkerProfileWithRelations | MinimalWorkerProfile | null) {
  if (!profile) {
    return null;
  }

  const base = {
    ...profile,
    aadhaarNumber: maskAadhaarNumber(profile.aadhaarNumber),
    skills: profile.skills.map((skill: WorkerSkillWithCategory) => ({
      id: skill.id,
      categoryId: skill.categoryId,
      certificationDocUrl: skill.certificationDocUrl,
      verifiedByAdmin: skill.verifiedByAdmin,
      yearsExperience: skill.yearsExperience,
      isPrimary: skill.isPrimary,
      createdAt: skill.createdAt,
      category: {
        id: skill.category.id,
        name: skill.category.name,
        slug: skill.category.slug,
        description: skill.category.description,
        iconUrl: skill.category.iconUrl
      }
    }))
  };

  return base;
}

async function ensureWorkerProfile(userId: string) {
  return prisma.workerProfile.upsert({
    where: { userId },
    create: {
      userId,
      onboardingStatus: "pending_documents"
    },
    update: {}
  });
}

async function getWorkerProfile(userId: string) {
  return prisma.workerProfile.findUnique({
    where: { userId },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          avatarUrl: true
        }
      },
      cityRelation: true,
      skills: {
        include: {
          category: true
        }
      }
    }
  });
}

async function getWorkerProfileOrThrow(userId: string) {
  const profile = await getWorkerProfile(userId);
  if (!profile) {
    throw new WorkerProfileNotFoundError();
  }

  return profile;
}

async function getWorkerProfileByIdOrThrow(workerProfileId: string) {
  const profile = await prisma.workerProfile.findUnique({
    where: { id: workerProfileId },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          avatarUrl: true
        }
      },
      cityRelation: true,
      skills: {
        include: {
          category: true
        }
      }
    }
  });

  if (!profile) {
    throw new WorkerProfileNotFoundError();
  }

  return profile;
}

function missingProfileFields(profile: MinimalWorkerProfile): string[] {
  const missingFields: string[] = [];

  if (!profile.fullName?.trim()) missingFields.push("fullName");
  if (!profile.addressLine1?.trim()) missingFields.push("addressLine1");
  if (!profile.city?.trim()) missingFields.push("city");
  if (!profile.pincode?.trim()) missingFields.push("pincode");
  if (!profile.aadhaarDocUrl?.trim()) missingFields.push("aadhaarDocUrl");
  if (!profile.skills.length) missingFields.push("skills");

  return missingFields;
}

async function uploadToCloudinaryFolder(fileUrl: string, folder: string, publicIdPrefix: string) {
  let buffer: Buffer;

  if (fileUrl.startsWith("data:")) {
    const base64 = fileUrl.split(",")[1] ?? "";
    buffer = Buffer.from(base64, "base64");
  } else {
    const response = await fetch(fileUrl);
    if (!response.ok) {
      throw new Error("Unable to fetch document file");
    }

    const arrayBuffer = await response.arrayBuffer();
    buffer = Buffer.from(arrayBuffer);
  }

  const uploaded = await uploadBufferToCloudinary(buffer, {
    folder,
    public_id: `${publicIdPrefix}-${Date.now()}`,
    resource_type: "auto",
    overwrite: true
  });

  return uploaded.secure_url;
}

export async function createOrGetProfile(userId: string) {
  const profile = await ensureWorkerProfile(userId);
  return normalizeProfile(await getWorkerProfileOrThrow(profile.userId));
}

export async function updatePersonalDetails(userId: string, details: ProfileDetails) {
  await ensureWorkerProfile(userId);

  await prisma.workerProfile.update({
    where: { userId },
    data: {
      fullName: details.fullName,
      dateOfBirth: toDate(details.dateOfBirth),
      addressLine1: details.addressLine1,
      city: details.city,
      pincode: details.pincode,
      bankAccountNumber: details.bankAccountNumber,
      bankIfsc: details.bankIfsc,
      upiId: details.upiId,
      aadhaarNumber: details.aadhaarNumber
    }
  });

  return normalizeProfile(await getWorkerProfileOrThrow(userId));
}

export async function uploadDocument(
  userId: string,
  docType: "aadhaar" | "skill_certification",
  fileUrl: string,
  categoryId?: string
) {
  const profile = await ensureWorkerProfile(userId);
  const folder = `veedufix/kyc/${userId}/${docType}`;
  const uploadedUrl = await uploadToCloudinaryFolder(fileUrl, folder, `kyc-${userId}-${docType}`);

  if (docType === "aadhaar") {
    await prisma.workerProfile.update({
      where: { id: profile.id },
      data: {
        aadhaarDocUrl: uploadedUrl
      }
    });

    return normalizeProfile(await getWorkerProfileOrThrow(userId));
  }

  if (!categoryId) {
    throw new Error("categoryId is required for skill certification uploads");
  }

  await prisma.workerSkill.upsert({
    where: {
      workerProfileId_categoryId: {
        workerProfileId: profile.id,
        categoryId
      }
    },
    create: {
      workerProfileId: profile.id,
      categoryId,
      certificationDocUrl: uploadedUrl,
      verifiedByAdmin: false
    },
    update: {
      certificationDocUrl: uploadedUrl,
      verifiedByAdmin: false
    }
  });

  return normalizeProfile(await getWorkerProfileOrThrow(userId));
}

export async function addSkill(userId: string, categoryId: string) {
  const profile = await ensureWorkerProfile(userId);

  await prisma.workerSkill.upsert({
    where: {
      workerProfileId_categoryId: {
        workerProfileId: profile.id,
        categoryId
      }
    },
    create: {
      workerProfileId: profile.id,
      categoryId
    },
    update: {}
  });

  return normalizeProfile(await getWorkerProfileOrThrow(userId));
}

export async function submitForReview(userId: string) {
  const profile = await ensureWorkerProfile(userId);
  const fullProfile = await prisma.workerProfile.findUnique({
    where: { id: profile.id },
    include: {
      skills: {
        include: {
          category: true
        }
      }
    }
  });

  if (!fullProfile) {
    throw new WorkerProfileNotFoundError();
  }

  const missingFields = missingProfileFields(fullProfile);
  if (missingFields.length > 0) {
    throw new IncompleteProfileError(missingFields);
  }

  await prisma.workerProfile.update({
    where: { id: profile.id },
    data: {
      onboardingStatus: "under_review",
      submittedAt: new Date(),
      rejectionReason: null,
      reviewedBy: null,
      reviewedAt: null,
      verificationStatus: VerificationStatus.PENDING
    }
  });

  return normalizeProfile(await getWorkerProfileOrThrow(userId));
}

export async function getOnboardingStatus(userId: string) {
  const profile = await ensureWorkerProfile(userId);
  return normalizeProfile(await getWorkerProfileOrThrow(profile.userId));
}

export async function listPendingReview(filters: PendingReviewFilters = {}) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 20;
  const skip = (page - 1) * limit;

  const where: Prisma.WorkerProfileWhereInput = {
    onboardingStatus: "under_review",
    ...(filters.city ? { city: filters.city } : {}),
    ...(filters.categoryId
      ? {
          skills: {
            some: {
              categoryId: filters.categoryId
            }
          }
        }
      : {})
  };

  const [total, items] = await prisma.$transaction([
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
            role: true,
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
      orderBy: [{ submittedAt: "asc" }, { createdAt: "asc" }],
      skip,
      take: limit
    })
  ]);

  return {
    items: items.map((item) => normalizeProfile(item)),
    page,
    limit,
    total,
    totalPages: Math.max(1, Math.ceil(total / limit))
  };
}

export async function approveWorker(workerProfileId: string, adminUserId: string) {
  const profile = await prisma.workerProfile.findUnique({
    where: { id: workerProfileId },
    include: {
      skills: true
    }
  });

  if (!profile) {
    throw new WorkerProfileNotFoundError();
  }

  await prisma.$transaction([
    prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        onboardingStatus: "approved",
        verificationStatus: VerificationStatus.VERIFIED,
        reviewedBy: adminUserId,
        reviewedAt: new Date(),
        rejectionReason: null
      }
    }),
    prisma.workerSkill.updateMany({
      where: { workerProfileId },
      data: { verifiedByAdmin: true }
    })
  ]);

  return normalizeProfile(await getWorkerProfileOrThrow(profile.userId));
}

export async function rejectWorker(workerProfileId: string, adminUserId: string, reason: string) {
  const profile = await prisma.workerProfile.findUnique({
    where: { id: workerProfileId }
  });

  if (!profile) {
    throw new WorkerProfileNotFoundError();
  }

  await prisma.workerProfile.update({
    where: { id: workerProfileId },
    data: {
      onboardingStatus: "rejected",
      verificationStatus: VerificationStatus.REJECTED,
      rejectionReason: reason,
      reviewedBy: adminUserId,
      reviewedAt: new Date()
    }
  });

  return normalizeProfile(await getWorkerProfileOrThrow(profile.userId));
}

export async function suspendWorker(workerProfileId: string, adminUserId: string, reason: string) {
  const profile = await prisma.workerProfile.findUnique({
    where: { id: workerProfileId }
  });

  if (!profile) {
    throw new WorkerProfileNotFoundError();
  }

  await prisma.workerProfile.update({
    where: { id: workerProfileId },
    data: {
      onboardingStatus: "suspended",
      verificationStatus: VerificationStatus.SUSPENDED,
      rejectionReason: reason,
      reviewedBy: adminUserId,
      reviewedAt: new Date()
    }
  });

  return normalizeProfile(await getWorkerProfileOrThrow(profile.userId));
}

export async function reinstateWorker(workerProfileId: string, adminUserId: string, note: string) {
  const profile = await prisma.workerProfile.findUnique({
    where: { id: workerProfileId }
  });

  if (!profile) {
    throw new WorkerProfileNotFoundError();
  }

  if (profile.onboardingStatus !== "suspended") {
    throw new WorkerStatusConflictError("Only suspended workers can be reinstated");
  }

  await prisma.workerProfile.update({
    where: { id: workerProfileId },
    data: {
      onboardingStatus: "approved",
      verificationStatus: VerificationStatus.VERIFIED,
      rejectionReason: null,
      reviewedBy: adminUserId,
      reviewedAt: new Date()
    }
  });

  logger.info(
    {
      workerProfileId,
      adminUserId,
      note
    },
    "Worker reinstated"
  );

  return normalizeProfile(await getWorkerProfileOrThrow(profile.userId));
}

export async function getWorkerDirectory(filters: WorkerDirectoryFilters = {}) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 20;
  const skip = (page - 1) * limit;

  const where: Prisma.WorkerProfileWhereInput = {
    ...(filters.city ? { city: filters.city } : {}),
    ...(filters.status ? { onboardingStatus: filters.status } : {}),
    ...(filters.categoryId
      ? {
          skills: {
            some: {
              categoryId: filters.categoryId
            }
          }
        }
      : {})
  };

  const [total, items] = await prisma.$transaction([
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
            role: true,
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
      orderBy: [{ createdAt: "desc" }],
      skip,
      take: limit
    })
  ]);

  const workerIds = items.map((item) => item.id);
  const [ratings, completedJobs] = await Promise.all([
    workerIds.length
      ? prisma.review.findMany({
          where: { workerId: { in: workerIds } },
          select: {
            workerId: true,
            rating: true
          }
        })
      : [],
    workerIds.length
      ? prisma.jobExecution.findMany({
          where: {
            status: "completed",
            booking: {
              workerId: { in: workerIds }
            }
          },
          select: {
            booking: {
              select: {
                workerId: true
              }
            }
          }
        })
      : []
  ]);

  const ratingMap = new Map<string, { total: number; count: number }>();
  for (const rating of ratings) {
    const aggregate = ratingMap.get(rating.workerId) ?? { total: 0, count: 0 };
    aggregate.total += rating.rating;
    aggregate.count += 1;
    ratingMap.set(rating.workerId, aggregate);
  }

  const completedJobsMap = new Map<string, number>();
  for (const execution of completedJobs) {
    const workerId = execution.booking.workerId;
    if (!workerId) {
      continue;
    }

    completedJobsMap.set(workerId, (completedJobsMap.get(workerId) ?? 0) + 1);
  }

  const normalizedItems = items.map((item: WorkerDirectoryProfile) => {
    const aggregate = ratingMap.get(item.id);
    const ratingAvg = aggregate && aggregate.count > 0 ? roundToTwo(aggregate.total / aggregate.count) : 0;

    return {
      ...normalizeProfile(item),
      ratingAvg,
      jobsCompletedCount: completedJobsMap.get(item.id) ?? 0
    };
  });

  return {
    items: normalizedItems,
    page,
    limit,
    total,
    totalPages: Math.max(1, Math.ceil(total / limit))
  };
}

export async function getWorkerHistory(workerProfileId: string) {
  const profile = await getWorkerProfileByIdOrThrow(workerProfileId);

  const [ratings] = await Promise.all([
    prisma.review.findMany({
      where: { workerId: workerProfileId },
      include: {
        booking: {
          select: {
            code: true,
            customer: {
              select: {
                name: true
              }
            }
          }
        },
        reviewer: {
          select: {
            id: true,
            name: true,
            avatarUrl: true
          }
        }
      },
      orderBy: [{ createdAt: "desc" }],
      take: 20
    })
  ]);

  const statusEvents = [
    {
      type: profile.onboardingStatus,
      status: profile.onboardingStatus,
      verificationStatus: profile.verificationStatus,
      note: profile.rejectionReason ?? null,
      reviewedBy: profile.reviewedBy ?? null,
      reviewedAt: profile.reviewedAt ?? null
    }
  ];

  return {
    worker: normalizeProfile(profile),
    noShowCount: profile.noShowCount,
    ratings: ratings.map((rating: WorkerRatingRecord) => ({
      id: rating.id,
      bookingCode: rating.booking.code,
      customerName: rating.booking.customer.name,
      reviewerName: rating.reviewer.name,
      reviewerAvatarUrl: rating.reviewer.avatarUrl ?? null,
      rating: rating.rating,
      comment: rating.comment,
      mediaUrls: rating.mediaUrls,
      createdAt: rating.createdAt,
      updatedAt: rating.updatedAt
    })),
    statusEvents
  };
}

export async function isWorkerEligible(userId: string): Promise<boolean> {
  const profile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: {
      onboardingStatus: true,
      verificationStatus: true
    }
  });

  return profile
    ? profile.onboardingStatus === "approved" && profile.verificationStatus === VerificationStatus.VERIFIED
    : false;
}

export function serializeWorkerProfile(profile: unknown) {
  return normalizeProfile(profile as WorkerProfileWithRelations | MinimalWorkerProfile | null);
}
