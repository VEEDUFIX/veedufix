import { z } from "zod";

const pincodeSchema = z
  .string()
  .trim()
  .regex(/^[1-9][0-9]{5}$/, "A valid 6-digit pincode is required");

const optionalPincodeSchema = z.preprocess((value) => {
  if (typeof value === "string" && value.trim() === "") {
    return null;
  }
  return value;
}, pincodeSchema.nullable().optional());

const slugSchema = z
  .string()
  .trim()
  .min(2)
  .max(120)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Slug must be lowercase kebab-case");

function validateCoverage(
  value: {
    pincode?: string | null;
    pincodeRangeStart?: string | null;
    pincodeRangeEnd?: string | null;
  },
  context: z.RefinementCtx
): void {
  const hasExactPincode = Boolean(value.pincode);
  const hasRangeStart = Boolean(value.pincodeRangeStart);
  const hasRangeEnd = Boolean(value.pincodeRangeEnd);

  if (!hasExactPincode && !(hasRangeStart && hasRangeEnd)) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["pincode"],
      message: "A valid 6-digit pincode is required"
    });
    return;
  }

  if ((hasRangeStart && !hasRangeEnd) || (!hasRangeStart && hasRangeEnd)) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: hasRangeStart ? ["pincodeRangeEnd"] : ["pincodeRangeStart"],
      message: "Both pincode range start and end are required together"
    });
  }

  if (value.pincodeRangeStart && value.pincodeRangeEnd) {
    const start = Number(value.pincodeRangeStart);
    const end = Number(value.pincodeRangeEnd);
    if (start > end) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["pincodeRangeEnd"],
        message: "Pincode range start must be less than or equal to end"
      });
    }
  }
}

export const serviceAreaCheckSchema = z.object({
  body: z.object({}).strict(),
  query: z.object({
    pincode: pincodeSchema,
    cityId: z.string().trim().min(1).optional(),
    city: z.string().trim().min(1).optional()
  }),
  params: z.object({}).strict()
});

export const listServiceAreasQuerySchema = z.object({
  body: z.object({}).strict(),
  query: z.object({
    cityId: z.string().trim().min(1).optional()
  }),
  params: z.object({}).strict()
});

export const serviceAreaIdParamsSchema = z.object({
  body: z.object({}).strict(),
  query: z.object({}).strict(),
  params: z.object({
    id: z.string().trim().min(1, "Service area id is required")
  })
});

export const createServiceAreaSchema = z.object({
  body: z.object({
    cityId: z.string().trim().min(1, "City is required"),
    name: z.string().trim().min(2).max(120),
    slug: slugSchema.optional(),
    pincode: optionalPincodeSchema,
    pincodeRangeStart: optionalPincodeSchema,
    pincodeRangeEnd: optionalPincodeSchema,
    isActive: z.boolean().optional()
  }).superRefine((value, context) => {
    validateCoverage(value, context);
  }),
  query: z.object({}).strict(),
  params: z.object({}).strict()
});

export const updateServiceAreaSchema = z.object({
  body: z.object({
    cityId: z.string().trim().min(1).optional(),
    name: z.string().trim().min(2).max(120).optional(),
    slug: slugSchema.optional(),
    pincode: optionalPincodeSchema,
    pincodeRangeStart: optionalPincodeSchema,
    pincodeRangeEnd: optionalPincodeSchema,
    isActive: z.boolean().optional()
  }).superRefine((value, context) => {
    const hasCoverageInput =
      value.pincode !== undefined ||
      value.pincodeRangeStart !== undefined ||
      value.pincodeRangeEnd !== undefined;

    if (!hasCoverageInput) {
      return;
    }

    validateCoverage(value, context);
  }),
  query: z.object({}).strict(),
  params: z.object({}).strict()
});
