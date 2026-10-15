import { Gender, Prisma, VerificationStatus } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { logger } from "../../lib/logger.js";
import { extractPublicIdFromUrl, generateSignedUrl, getCloudinaryFormatFromUrl } from "../../lib/cloudinary.js";
import { maskWorkerFinancialFields } from "../../lib/mask-worker.js";
import { env } from "../../config/env.js";

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
  gender?: Gender;
  dateOfBirth?: Date | string;
  addressLine1?: string;
  alternatePhone?: string;
  city?: string;
  pincode?: string;
  serviceAreas?: string;
  serviceAreaIds?: string[];
  workType?: "FULL_TIME" | "PART_TIME";
  acceptsUrgentJobs?: boolean;
  serviceRadiusKm?: number;
  bankAccountNumber?: string;
  bankIfsc?: string;
  upiId?: string;
  aadhaarNumber?: string;
  toolsOwned?: string[];
  emergencyContactName?: string;
  emergencyContactPhone?: string;
  agreementAccepted?: boolean;
  dataConsentAccepted?: boolean;
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
  search?: string;
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
    availability: true;
  };
}>;

type MinimalWorkerProfile = Prisma.WorkerProfileGetPayload<{
  include: {
    skills: {
      include: {
        category: true;
      };
    };
    availability: true;
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
    availability: true;
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

function toDate(value: Date | string | undefined): Date | undefined {
  if (!value) {
    return undefined;
  }

  return value instanceof Date ? value : new Date(value);
}

/**
 * Transforms a raw Prisma WorkerProfile into a client-safe shape:
 * - Masks sensitive financial fields (aadhaarNumber, bankAccountNumber, upiId)
 *   via the shared maskWorkerFinancialFields utility.
 * - bankIfsc is intentionally left unmasked (public bank branch code).
 * - Strips redundant skill relation data down to only what the client needs.
 */
function normalizeProfile(profile: WorkerProfileWithRelations | MinimalWorkerProfile | null) {
  if (!profile) {
    return null;
  }

  const relations = profile as unknown as {
    skills?: WorkerSkillWithCategory[];
    availability?: Array<{
      dayOfWeek: number;
      startTime: string;
      endTime: string;
    }>;
    serviceAreaAssignments?: Array<{
      serviceAreaId: string;
      serviceArea: {
        id: string;
        name: string;
        slug: string;
        cityId: string;
        city: { id: string; name: string; stateId: string; districtId: string | null; state: string; district: string | null };
        assignedPincodes: Array<{ pincode: string }>;
      };
    }>;
  };
  const skills = Array.isArray(relations.skills) ? relations.skills : [];
  const availability = Array.isArray(relations.availability)
    ? relations.availability
    : [];
  const serviceAreaAssignments = Array.isArray(relations.serviceAreaAssignments)
    ? relations.serviceAreaAssignments
    : [];

  // Destructure raw KYC doc fields — never send these to any client.
  const { aadhaarDocUrl, aadhaarDocPublicId, serviceAreaAssignments: _rawAssignments, ...rest } = maskWorkerFinancialFields(profile) as typeof profile & {
    aadhaarDocPublicId?: string | null;
    serviceAreaAssignments?: unknown;
  };

  const base = {
    ...rest,
    // Boolean presence indicator replaces the raw URL in every response.
    hasAadhaarDoc: Boolean(aadhaarDocUrl?.trim()),
    hasAvailability: Boolean(availability?.length),
    serviceAreaIds: serviceAreaAssignments.map((assignment) => assignment.serviceAreaId),
    assignedServiceAreas: serviceAreaAssignments.map((assignment) => ({
      id: assignment.serviceArea.id,
      name: assignment.serviceArea.name,
      slug: assignment.serviceArea.slug,
      cityId: assignment.serviceArea.cityId,
      city: assignment.serviceArea.city,
      pincodes: assignment.serviceArea.assignedPincodes.map((item) => item.pincode)
    })),
    availabilitySlots: (availability ?? []).map((slot: any) => ({
      dayOfWeek: slot.dayOfWeek,
      startTime: slot.startTime,
      endTime: slot.endTime
    })),
    skills: skills.flatMap((skill: WorkerSkillWithCategory) => {
      if (!skill.category) return [];
      return [{
      id: skill.id,
      categoryId: skill.categoryId,
      // Boolean presence indicator — raw certificationDocUrl is intentionally omitted.
      hasCertificationDoc: Boolean(skill.certificationDocUrl?.trim()),
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
      }];
    })
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
      },
      availability: true
      ,serviceAreaAssignments: {
        include: {
          serviceArea: {
            include: {
              assignedPincodes: { select: { pincode: true } },
              city: true
            }
          }
        },
        orderBy: { serviceAreaId: "asc" }
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
      },
      availability: true,
      serviceAreaAssignments: {
        include: {
          serviceArea: {
            include: {
              assignedPincodes: { select: { pincode: true } },
              city: true
            }
          }
        },
        orderBy: { serviceAreaId: "asc" }
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
  const hasUpi = Boolean(profile.upiId?.trim());
  const hasBankFallback = Boolean(
    profile.bankAccountNumber &&
      /^\d{9,18}$/.test(profile.bankAccountNumber.trim()) &&
      profile.bankIfsc?.trim()
  );

  if (!profile.fullName?.trim()) missingFields.push("fullName");
  if (!profile.aadhaarNumber?.trim()) missingFields.push("aadhaarNumber");
  if (!profile.addressLine1?.trim()) missingFields.push("addressLine1");
  if (!profile.city?.trim()) missingFields.push("city");
  if (!profile.pincode?.trim()) missingFields.push("pincode");
  if (!profile.serviceAreas?.trim()) missingFields.push("serviceAreas");
  if (!profile.aadhaarDocUrl?.trim()) missingFields.push("aadhaarDocUrl");
  if (!hasUpi && !hasBankFallback) missingFields.push("upiId");
  if (!profile.skills.length) missingFields.push("skills");
  if (!profile.availability.length) missingFields.push("availability");
  if (!profile.emergencyContactName?.trim()) missingFields.push("emergencyContactName");
  if (!profile.emergencyContactPhone?.trim()) missingFields.push("emergencyContactPhone");
  if (!profile.agreementAcceptedAt) missingFields.push("agreementAcceptedAt");
  if (!profile.dataConsentAcceptedAt) missingFields.push("dataConsentAcceptedAt");

  return missingFields;
}

/** Accept only this worker's authenticated Cloudinary upload; never fetch a client URL. */
async function uploadKycDocument(
  userId: string,
  fileUrl: string
): Promise<{ url: string; publicId: string }> {
  let parsed: URL;
  try {
    parsed = new URL(fileUrl);
  } catch {
    throw AppError.badRequest("Upload the document before submitting it");
  }

  const publicId = extractPublicIdFromUrl(fileUrl);
  const expectedPath = `/${env.CLOUDINARY_CLOUD_NAME}/image/authenticated/`;
  if (
    parsed.protocol !== "https:" ||
    parsed.hostname !== "res.cloudinary.com" ||
    parsed.port !== "" ||
    !parsed.pathname.startsWith(expectedPath) ||
    !publicId?.startsWith(`veedufix/documents/${userId}/`)
  ) {
    throw AppError.badRequest("Upload the document using the secure document uploader");
  }

  return { url: fileUrl, publicId };
}

export async function createOrGetProfile(userId: string) {
  const profile = await ensureWorkerProfile(userId);
  return normalizeProfile(await getWorkerProfileOrThrow(profile.userId));
}

export async function updatePersonalDetails(userId: string, details: ProfileDetails) {
  await ensureWorkerProfile(userId);
  const current = await prisma.workerProfile.findUnique({
    where: { userId },
    select: {
      id: true,
      fullName: true,
      verificationStatus: true,
      onboardingStatus: true,
      bankAccountNumber: true,
      bankIfsc: true,
      upiId: true,
      agreementAcceptedAt: true,
      dataConsentAcceptedAt: true
    }
  });

  if (
    current?.verificationStatus === VerificationStatus.VERIFIED &&
    details.fullName !== undefined &&
    details.fullName.trim() !== current.fullName
  ) {
    throw new WorkerStatusConflictError(
      "Verified identity changes require a support review"
    );
  }

  const serviceAreaIds = details.serviceAreaIds;
  let selectedServiceAreas: Array<{
    id: string;
    name: string;
    cityId: string;
    city: { name: string };
  }> = [];
  if (serviceAreaIds !== undefined) {
    if (
      current?.onboardingStatus === "approved" ||
      current?.onboardingStatus === "under_review"
    ) {
      const currentAssignments = await prisma.workerProfileServiceArea.findMany({
        where: { workerProfileId: current.id },
        select: { serviceAreaId: true }
      });
      const currentIds = new Set(
        currentAssignments.map((assignment) => assignment.serviceAreaId)
      );
      const requestedIds = new Set(serviceAreaIds);
      const serviceAreasChanged =
        currentIds.size !== requestedIds.size ||
        [...requestedIds].some((serviceAreaId) => !currentIds.has(serviceAreaId));

      if (serviceAreasChanged) {
        throw new WorkerStatusConflictError(
          "Partner service-area changes require an admin review"
        );
      }
    }
    const queriedServiceAreas = await prisma.serviceArea.findMany({
      where: {
        id: { in: serviceAreaIds },
        isActive: true,
        city: { isActive: true }
      },
      select: { id: true, name: true, cityId: true, city: { select: { name: true } } }
    });
    selectedServiceAreas = queriedServiceAreas as typeof selectedServiceAreas;
    if (selectedServiceAreas.length !== serviceAreaIds.length) {
      throw AppError.badRequest("Select only active, configured Partner service areas");
    }
  }

  const payoutChangeRequested =
    (details.bankAccountNumber !== undefined && details.bankAccountNumber !== current?.bankAccountNumber) ||
    (details.bankIfsc !== undefined && details.bankIfsc !== current?.bankIfsc) ||
    (details.upiId !== undefined && details.upiId !== current?.upiId);
  if (
    payoutChangeRequested &&
    (current?.onboardingStatus === "approved" || current?.onboardingStatus === "under_review")
  ) {
    throw new WorkerStatusConflictError(
      "Payout details cannot be changed after submission. Contact support to request an update"
    );
  }

  await prisma.$transaction(async (tx) => {
    if (serviceAreaIds !== undefined && current) {
      await tx.$queryRaw`SELECT "id" FROM "WorkerProfile" WHERE "userId" = ${userId} FOR UPDATE`;
      const lockedProfile = await tx.workerProfile.findUnique({
        where: { userId },
        select: { id: true, onboardingStatus: true }
      });
      if (
        lockedProfile?.onboardingStatus === "approved" ||
        lockedProfile?.onboardingStatus === "under_review"
      ) {
        const lockedAssignments = await tx.workerProfileServiceArea.findMany({
          where: { workerProfileId: lockedProfile.id },
          select: { serviceAreaId: true }
        });
        const lockedIds = new Set(lockedAssignments.map((assignment) => assignment.serviceAreaId));
        const requestedIds = new Set(serviceAreaIds);
        const changed = lockedIds.size !== requestedIds.size ||
          [...requestedIds].some((serviceAreaId) => !lockedIds.has(serviceAreaId));
        if (changed) {
          throw new WorkerStatusConflictError(
            "Partner service-area changes require an admin review"
          );
        }
      }
    }
    await tx.workerProfile.update({
      where: { userId },
      data: {
      fullName: details.fullName,
      gender: details.gender,
      dateOfBirth: toDate(details.dateOfBirth),
      addressLine1: details.addressLine1,
      alternatePhone: details.alternatePhone,
      city: serviceAreaIds !== undefined
        ? [...new Set(selectedServiceAreas.map((area) => area.city.name))].join(", ").slice(0, 120)
        : details.city,
      cityId: serviceAreaIds !== undefined
        ? [...new Set(selectedServiceAreas.map((area) => area.cityId))].length === 1
          ? selectedServiceAreas[0]?.cityId
          : null
        : undefined,
      pincode: details.pincode,
      serviceAreas: serviceAreaIds !== undefined
        ? selectedServiceAreas.map((area) => area.name).join(", ").slice(0, 500)
        : details.serviceAreas,
      workType: details.workType,
      acceptsUrgentJobs: details.acceptsUrgentJobs,
      serviceRadiusKm: details.serviceRadiusKm,
      bankAccountNumber: details.bankAccountNumber,
      bankIfsc: details.bankIfsc,
      upiId: details.upiId,
      aadhaarNumber: details.aadhaarNumber,
      toolsOwned: details.toolsOwned,
      emergencyContactName: details.emergencyContactName,
      emergencyContactPhone: details.emergencyContactPhone,
      agreementAcceptedAt: details.agreementAccepted ? current?.agreementAcceptedAt ?? new Date() : undefined,
      dataConsentAcceptedAt: details.dataConsentAccepted ? current?.dataConsentAcceptedAt ?? new Date() : undefined
      }
    });
    if (serviceAreaIds !== undefined) {
      await tx.workerProfileServiceArea.deleteMany({
        where: { workerProfileId: current!.id }
      });
      await tx.workerProfileServiceArea.createMany({
        data: selectedServiceAreas.map((area) => ({
          workerProfileId: current!.id,
          serviceAreaId: area.id
        }))
      });
    }
  });

  return normalizeProfile(await getWorkerProfileOrThrow(userId));
}

function payoutRequestStatus(request: {
  id: string;
  status: string;
  rejectionReason: string | null;
  reviewedAt: Date | null;
  createdAt: Date;
}) {
  return {
    id: request.id,
    status: request.status,
    rejectionReason: request.rejectionReason,
    reviewedAt: request.reviewedAt,
    createdAt: request.createdAt
  };
}

export async function getMyPayoutChangeRequest(userId: string) {
  const profile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });
  if (!profile) throw new WorkerProfileNotFoundError();

  const request = await prisma.workerPayoutChangeRequest.findFirst({
    where: { workerProfileId: profile.id },
    orderBy: { createdAt: "desc" },
    select: { id: true, status: true, rejectionReason: true, reviewedAt: true, createdAt: true }
  });
  return { request: request ? payoutRequestStatus(request) : null };
}

export async function submitPayoutChangeRequest(
  userId: string,
  details: { bankAccountNumber?: string; bankIfsc?: string; upiId?: string }
) {
  const profile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true, onboardingStatus: true }
  });
  if (!profile) throw new WorkerProfileNotFoundError();
  if (profile.onboardingStatus !== "approved") {
    throw new WorkerStatusConflictError("Only approved workers can request payout account changes");
  }

  try {
    const request = await prisma.workerPayoutChangeRequest.create({
      data: {
        workerProfileId: profile.id,
        pendingKey: profile.id,
        bankAccountNumber: details.bankAccountNumber,
        bankIfsc: details.bankIfsc?.toUpperCase(),
        upiId: details.upiId
      },
      select: { id: true, status: true, rejectionReason: true, reviewedAt: true, createdAt: true }
    });
    return { request: payoutRequestStatus(request) };
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      throw new WorkerStatusConflictError("A payout account change is already awaiting review");
    }
    throw error;
  }
}

export async function listPayoutChangeRequests() {
  const items = await prisma.workerPayoutChangeRequest.findMany({
    where: { status: "pending" },
    include: {
      workerProfile: {
        select: {
          id: true,
          fullName: true,
          city: true,
          user: { select: { phone: true, email: true } }
        }
      }
    },
    orderBy: { createdAt: "asc" },
    take: 100
  });
  return {
    items: items.map(({ pendingKey: _pendingKey, ...request }) => request),
    total: items.length
  };
}

export async function approvePayoutChangeRequest(requestId: string, adminId: string) {
  return prisma.$transaction(async (tx) => {
    const request = await tx.workerPayoutChangeRequest.findUnique({ where: { id: requestId } });
    if (!request || request.status !== "pending") {
      throw new WorkerStatusConflictError("This payout account request is no longer pending");
    }
    await tx.workerProfile.update({
      where: { id: request.workerProfileId },
      data: {
        ...(request.bankAccountNumber && request.bankIfsc
          ? {
              bankAccountNumber: request.bankAccountNumber,
              bankIfsc: request.bankIfsc
            }
          : {}),
        ...(request.upiId ? { upiId: request.upiId } : {})
      }
    });
    const claimed = await tx.workerPayoutChangeRequest.updateMany({
      where: { id: requestId, status: "pending" },
      data: { status: "approved", pendingKey: null, reviewedBy: adminId, reviewedAt: new Date() }
    });
    if (claimed.count !== 1) {
      throw new WorkerStatusConflictError("This payout account request is no longer pending");
    }
    return { id: requestId, workerProfileId: request.workerProfileId };
  });
}

export async function rejectPayoutChangeRequest(requestId: string, adminId: string, reason: string) {
  const result = await prisma.workerPayoutChangeRequest.updateMany({
    where: { id: requestId, status: "pending" },
    data: {
      status: "rejected",
      pendingKey: null,
      rejectionReason: reason.trim(),
      reviewedBy: adminId,
      reviewedAt: new Date()
    }
  });
  if (result.count !== 1) {
    throw new WorkerStatusConflictError("This payout account request is no longer pending");
  }
  return { id: requestId };
}

export async function uploadDocument(
  userId: string,
  docType: "aadhaar" | "skill_certification",
  fileUrl: string,
  categoryId?: string
) {
  const profile = await ensureWorkerProfile(userId);
  const { url, publicId } = await uploadKycDocument(userId, fileUrl);

  if (docType === "aadhaar") {
    await prisma.workerProfile.update({
      where: { id: profile.id },
      data: {
        aadhaarDocUrl: url,
        aadhaarDocPublicId: publicId
      }
    });

    return normalizeProfile(await getWorkerProfileOrThrow(userId));
  }

  if (!categoryId) {
    throw AppError.badRequest("categoryId is required for skill certification uploads");
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
      certificationDocUrl: url,
      certificationDocPublicId: publicId,
      verifiedByAdmin: false
    },
    update: {
      certificationDocUrl: url,
      certificationDocPublicId: publicId,
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

export async function addService(userId: string, serviceId: string) {
  const profile = await ensureWorkerProfile(userId);
  const service = await prisma.service.findUnique({
    where: { id: serviceId },
    select: { id: true, categoryId: true }
  });

  if (!service) {
    throw new WorkerProfileNotFoundError("Service not found");
  }

  await prisma.workerService.upsert({
    where: {
      workerId_serviceId: {
        workerId: profile.id,
        serviceId: service.id
      }
    },
    create: {
      workerId: profile.id,
      serviceId: service.id
    },
    update: {}
  });

  await addSkill(userId, service.categoryId);

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
      },
      availability: true
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
        },
        availability: true
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

export async function getWorkerReviewProfile(workerProfileId: string) {
  return normalizeProfile(await getWorkerProfileByIdOrThrow(workerProfileId));
}

async function requireActiveServiceAreaAssignment(
  workerProfileId: string,
  client: Prisma.TransactionClient | typeof prisma = prisma
) {
  const activeAssignmentCount = await client.workerProfileServiceArea.count({
    where: {
      workerProfileId,
      serviceArea: { isActive: true, city: { isActive: true } }
    }
  });
  if (activeAssignmentCount === 0) {
    throw new WorkerStatusConflictError(
      "Assign at least one active Partner service area before approval"
    );
  }
}

export async function approveWorker(workerProfileId: string, adminUserId: string) {
  const userId = await prisma.$transaction(async (tx) => {
    await tx.$queryRaw`SELECT "id" FROM "WorkerProfile" WHERE "id" = ${workerProfileId} FOR UPDATE`;
    const profile = await tx.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: { userId: true }
    });
    if (!profile) throw new WorkerProfileNotFoundError();

    await requireActiveServiceAreaAssignment(workerProfileId, tx);
    await tx.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        onboardingStatus: "approved",
        verificationStatus: VerificationStatus.VERIFIED,
        reviewedBy: adminUserId,
        reviewedAt: new Date(),
        rejectionReason: null
      }
    });
    await tx.workerSkill.updateMany({
      where: { workerProfileId },
      data: { verifiedByAdmin: true }
    })
    return profile.userId;
  });

  return normalizeProfile(await getWorkerProfileOrThrow(userId));
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
  const userId = await prisma.$transaction(async (tx) => {
    await tx.$queryRaw`SELECT "id" FROM "WorkerProfile" WHERE "id" = ${workerProfileId} FOR UPDATE`;
    const profile = await tx.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: { userId: true, onboardingStatus: true }
    });
    if (!profile) throw new WorkerProfileNotFoundError();
    if (profile.onboardingStatus !== "suspended") {
      throw new WorkerStatusConflictError("Only suspended workers can be reinstated");
    }

    await requireActiveServiceAreaAssignment(workerProfileId, tx);
    await tx.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        onboardingStatus: "approved",
        verificationStatus: VerificationStatus.VERIFIED,
        rejectionReason: null,
        reviewedBy: adminUserId,
        reviewedAt: new Date()
      }
    });
    return profile.userId;
  });

  logger.info(
    {
      workerProfileId,
      adminUserId,
      note
    },
    "Worker reinstated"
  );

  return normalizeProfile(await getWorkerProfileOrThrow(userId));
}

export async function getWorkerDirectory(filters: WorkerDirectoryFilters = {}) {
  const page = filters.page ?? 1;
  const limit = filters.limit ?? 20;
  const skip = (page - 1) * limit;

  const searchFilter: Prisma.WorkerProfileWhereInput | undefined =
    filters.search && filters.search.trim()
      ? {
          OR: [
            { fullName: { contains: filters.search.trim(), mode: "insensitive" } },
            { user: { name: { contains: filters.search.trim(), mode: "insensitive" } } },
            { user: { email: { contains: filters.search.trim(), mode: "insensitive" } } },
            { user: { phone: { contains: filters.search.trim(), mode: "insensitive" } } }
          ]
        }
      : undefined;

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
      : {}),
    ...(searchFilter ?? {})
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
        },
        availability: true
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
          where: { workerId: { in: workerIds }, moderationStatus: "published" },
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
      where: { workerId: workerProfileId, moderationStatus: "published" },
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

// ---------------------------------------------------------------------------
// KYC Document signed-URL helpers
// ---------------------------------------------------------------------------
// Each function retrieves the stored public_id from the DB, then delegates
// to generateSignedUrl() to produce a 5-minute signed Cloudinary URL.
// Callers must already have verified authorization (owner or ADMIN) before
// invoking these — these functions do NOT perform auth checks.
// ---------------------------------------------------------------------------

/**
 * Returns a short-lived signed URL for a worker's Aadhaar document.
 * Called by the WORKER (self) via getOwnAadhaarSignedUrl.
 */
export async function getAadhaarSignedUrl(workerProfileId: string): Promise<string> {
  const profile = await prisma.workerProfile.findUnique({
    where: { id: workerProfileId },
    select: { aadhaarDocPublicId: true, aadhaarDocUrl: true }
  });

  if (!profile) throw new WorkerProfileNotFoundError();

  const publicId = profile.aadhaarDocPublicId;
  const format = getCloudinaryFormatFromUrl(profile.aadhaarDocUrl ?? "");
  if (!publicId || !format) {
    throw new WorkerProfileNotFoundError("No Aadhaar document found for this profile");
  }

  return generateSignedUrl(publicId, format);
}

/**
 * Looks up the authenticated worker's own profile by userId, then calls
 * getAadhaarSignedUrl.
 */
export async function getOwnAadhaarSignedUrl(userId: string): Promise<string> {
  const profile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!profile) throw new WorkerProfileNotFoundError();

  return getAadhaarSignedUrl(profile.id);
}

/**
 * Returns a short-lived signed URL for a WorkerSkill certification document.
 * When workerProfileId is supplied, ownership is verified before returning
 * the URL (used by admin path to ensure the skillId actually belongs to the
 * named profile, preventing cross-profile enumeration).
 */
export async function getSkillCertSignedUrl(
  skillId: string,
  workerProfileId?: string
): Promise<string> {
  const skill = await prisma.workerSkill.findUnique({
    where: { id: skillId },
    select: { certificationDocPublicId: true, certificationDocUrl: true, workerProfileId: true }
  });

  if (!skill) throw new WorkerProfileNotFoundError("Skill not found");

  if (workerProfileId && skill.workerProfileId !== workerProfileId) {
    throw new WorkerProfileNotFoundError("Skill does not belong to this profile");
  }

  const format = getCloudinaryFormatFromUrl(skill.certificationDocUrl ?? "");
  if (!skill.certificationDocPublicId || !format) {
    throw new WorkerProfileNotFoundError("No certification document found for this skill");
  }

  return generateSignedUrl(skill.certificationDocPublicId, format);
}

/**
 * Looks up the authenticated worker's own profile by userId, verifies the
 * skill belongs to them, then calls getSkillCertSignedUrl.
 */
export async function getOwnSkillCertSignedUrl(
  userId: string,
  skillId: string
): Promise<string> {
  const profile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!profile) throw new WorkerProfileNotFoundError();

  return getSkillCertSignedUrl(skillId, profile.id);
}
