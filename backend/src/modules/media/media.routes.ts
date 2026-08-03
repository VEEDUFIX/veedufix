import { NextFunction, Request, Response, Router } from "express";
import multer from "multer";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  uploadAvatarHandler,
  uploadWorkerDocumentHandler,
  uploadWorkerPortfolioHandler
} from "./media.controller.js";
import {
  ALLOWED_IMAGE_MIME_TYPES,
  avatarUploadSchema,
  documentUploadSchema,
  portfolioUploadSchema
} from "./media.schemas.js";

/**
 * Multer instance shared by all three media upload endpoints.
 *
 * Size limit: 10 MB (server-side cap before Cloudinary upload).
 * MIME filter: JPEG and PNG only — consistent with the upload module.
 *
 * Multer errors (file-too-large, wrong MIME type) are forwarded as Express
 * errors and caught by the route-level error wrapper below, which converts
 * them to 400 responses instead of letting them propagate to the global 500
 * error handler.
 */
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024
  },
  fileFilter: (_request, file, callback) => {
    if (!(ALLOWED_IMAGE_MIME_TYPES as readonly string[]).includes(file.mimetype)) {
      callback(new Error(`Only ${ALLOWED_IMAGE_MIME_TYPES.join(" and ")} files are allowed`));
      return;
    }

    callback(null, true);
  }
});

/**
 * Express error-handling middleware that intercepts multer errors (wrong MIME
 * type, file too large) and returns a structured 400 instead of a 500.
 * Must be placed immediately after upload.single() on each route.
 */
function handleMulterError(error: unknown, _request: Request, response: Response, next: NextFunction): void {
  if (error instanceof multer.MulterError) {
    if (error.code === "LIMIT_FILE_SIZE") {
      response.status(400).json({ message: "File is too large. Maximum allowed size is 10 MB." });
      return;
    }
    response.status(400).json({ message: "Upload failed" });
    return;
  }

  if (error instanceof Error) {
    // fileFilter rejects arrive here as plain Error instances
    response.status(400).json({ message: "Upload failed" });
    return;
  }

  next(error);
}

export const mediaRouter = Router();

mediaRouter.post(
  "/avatar",
  requireAuth,
  upload.single("file"),
  handleMulterError,
  validate(avatarUploadSchema),
  uploadAvatarHandler
);

mediaRouter.post(
  "/workers/portfolio",
  requireAuth,
  requireRole("WORKER"),
  upload.single("file"),
  handleMulterError,
  validate(portfolioUploadSchema),
  uploadWorkerPortfolioHandler
);

mediaRouter.post(
  "/workers/document",
  requireAuth,
  requireRole("WORKER"),
  upload.single("file"),
  handleMulterError,
  validate(documentUploadSchema),
  uploadWorkerDocumentHandler
);
