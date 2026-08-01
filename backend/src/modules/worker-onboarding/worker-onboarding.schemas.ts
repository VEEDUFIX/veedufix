import { z } from "zod";

const baseProfileBodySchema = z.object({
  fullName: z.string().trim().min(2).max(120).optional(),
  gender: z.enum(["MALE", "FEMALE", "OTHER", "PREFER_NOT_TO_SAY"]).optional(),
  dateOfBirth: z.coerce.date().optional(),
  addressLine1: z.string().trim().min(3).max(255).optional(),
  alternatePhone: z.string().trim().min(7).max(20).optional(),
  city: z.string().trim().min(2).max(120).optional(),
  pincode: z.string().trim().min(3).max(20).optional(),
  bankAccountNumber: z.string().trim().regex(/^\d{9,18}$/, "Bank account number must contain 9 to 18 digits").optional(),
  bankIfsc: z.string().trim().min(6).max(20).optional(),
  upiId: z.string().trim().min(3).max(128).optional(),
  aadhaarNumber: z.string().trim().regex(/^\d{12}$/, "Aadhaar number must contain exactly 12 digits").optional(),
  toolsOwned: z.array(z.string().trim().min(1).max(80)).max(20).optional(),
  emergencyContactName: z.string().trim().min(2).max(120).optional(),
  emergencyContactPhone: z.string().trim().min(7).max(20).optional(),
  agreementAccepted: z.boolean().optional(),
  dataConsentAccepted: z.boolean().optional()
});

export const updateProfileSchema = z.object({
  body: baseProfileBodySchema,
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

export const uploadDocumentSchema = z.object({
  body: z
    .object({
      docType: z.enum(["aadhaar", "skill_certification"]),
      fileUrl: z.string().trim().min(1),
      categoryId: z.string().trim().min(1).optional()
    })
    .superRefine((value, ctx) => {
      if (value.docType === "skill_certification" && !value.categoryId) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["categoryId"],
          message: "categoryId is required for skill_certification uploads"
        });
      }
    }),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

export const addSkillSchema = z.object({
  body: z.object({
    categoryId: z.string().trim().min(1)
  }),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

export const addServiceSchema = z.object({
  body: z.object({
    serviceId: z.string().trim().min(1)
  }),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

export const submitForReviewSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

export const onboardingStatusSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

export const pendingReviewQuerySchema = z.object({
  body: z.object({}).optional(),
  query: z.object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    city: z.string().trim().min(1).optional(),
    categoryId: z.string().trim().min(1).optional()
  }),
  params: z.object({}).optional()
});

export const adminProfileParamsSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({
    profileId: z.string().trim().min(1)
  })
});

export const rejectProfileSchema = z.object({
  body: z.object({
    reason: z.string().trim().min(3).max(500)
  }),
  query: z.object({}).optional(),
  params: z.object({
    profileId: z.string().trim().min(1)
  })
});

export const suspendProfileSchema = rejectProfileSchema;

export const reinstateProfileSchema = z.object({
  body: z.object({
    note: z.string().trim().min(3).max(500)
  }),
  query: z.object({}).optional(),
  params: z.object({
    profileId: z.string().trim().min(1)
  })
});

export const adminWorkersQuerySchema = z.object({
  body: z.object({}).optional(),
  query: z.object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    city: z.string().trim().min(1).optional(),
    categoryId: z.string().trim().min(1).optional(),
    status: z.enum(["pending_documents", "under_review", "approved", "rejected", "suspended"]).optional(),
    search: z.string().trim().max(120).optional()
  }),
  params: z.object({}).optional()
});

export const adminWorkerHistoryParamsSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({
    profileId: z.string().trim().min(1)
  })
});

// ---------------------------------------------------------------------------
// KYC document access schemas
// ---------------------------------------------------------------------------

/** Worker self-access: GET /worker/onboarding/documents/aadhaar (no params needed) */
export const workerDocAadhaarSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

/** Worker self-access: GET /worker/onboarding/documents/skills/:skillId/certification */
export const workerDocSkillParamsSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({
    skillId: z.string().trim().min(1)
  })
});

/** Admin access: GET /admin/worker-review/:profileId/documents/aadhaar */
export const adminDocAadhaarParamsSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({
    profileId: z.string().trim().min(1)
  })
});

/** Admin access: GET /admin/worker-review/:profileId/documents/skills/:skillId/certification */
export const adminDocSkillParamsSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({
    profileId: z.string().trim().min(1),
    skillId: z.string().trim().min(1)
  })
});
