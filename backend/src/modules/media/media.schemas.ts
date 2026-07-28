import { z } from "zod";

/**
 * Allowed MIME types for all media uploads across the platform.
 * These match the fileFilter enforced by multer in media.routes.ts —
 * keeping them co-located here means they can be referenced from tests.
 */
export const ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png"] as const;

/**
 * Maximum upload size in bytes (10 MB).
 * This mirrors the multer `limits.fileSize` in media.routes.ts.
 * Multer enforces it before the request reaches the controller, so
 * we document it here rather than re-validating in the schema.
 */
export const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024;

// ---------------------------------------------------------------------------
// POST /api/media/avatar
// multipart/form-data — file field: "file"  (required, enforced in controller)
// No additional body fields required.
// ---------------------------------------------------------------------------
export const avatarUploadSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

// ---------------------------------------------------------------------------
// POST /api/media/workers/portfolio
// multipart/form-data — file field: "file"  (required, enforced in controller)
// Optional body field: caption
// ---------------------------------------------------------------------------
export const portfolioUploadSchema = z.object({
  body: z
    .object({
      caption: z.string().trim().max(200).optional()
    })
    .optional(),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

// ---------------------------------------------------------------------------
// POST /api/media/workers/document
// multipart/form-data — file field: "file"  (required, enforced in controller)
// Required body field: type (enum of known document kinds)
// ---------------------------------------------------------------------------
export const DOCUMENT_TYPES = [
  "aadhaar",
  "pan",
  "driving_license",
  "passport",
  "voter_id",
  "other"
] as const;

export type DocumentType = (typeof DOCUMENT_TYPES)[number];

export const documentUploadSchema = z.object({
  body: z.object({
    type: z.enum(DOCUMENT_TYPES, {
      errorMap: () => ({
        message: `type must be one of: ${DOCUMENT_TYPES.join(", ")}`
      })
    })
  }),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});
