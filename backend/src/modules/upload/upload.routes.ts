import { NextFunction, Request, Response, Router } from "express";
import multer from "multer";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  confirmJobPhotoSchema,
  uploadJobPhotoSchema,
  uploadSignatureSchema
} from "./upload.schemas.js";
import {
  confirmJobPhotoHandler,
  generateUploadSignatureHandler,
  uploadJobPhotoHandler
} from "./upload.controller.js";

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024
  },
  fileFilter: (_request, file, callback) => {
    if (file.mimetype !== "image/jpeg" && file.mimetype !== "image/png") {
      callback(new Error(`Unsupported file type: ${file.mimetype}. Only JPEG and PNG images are allowed.`));
      return;
    }

    callback(null, true);
  }
});

/**
 * Converts multer errors (wrong MIME type, file too large) into structured
 * 400 responses instead of letting them fall through to the global 500 handler.
 */
function handleMulterError(error: unknown, _request: Request, response: Response, next: NextFunction): void {
  if (error instanceof multer.MulterError) {
    if (error.code === "LIMIT_FILE_SIZE") {
      response.status(400).json({ message: "File is too large. Maximum allowed size is 5 MB." });
      return;
    }
    response.status(400).json({ message: "Upload failed: " + error.message });
    return;
  }
  if (error instanceof Error) {
    // fileFilter rejections arrive as plain Error instances.
    response.status(400).json({ message: error.message });
    return;
  }
  next(error);
}

export const uploadRouter = Router();

uploadRouter.post(
  "/signature",
  requireAuth,
  requireRole("WORKER"),
  validate(uploadSignatureSchema),
  generateUploadSignatureHandler
);

uploadRouter.post(
  "/job-photo",
  requireAuth,
  requireRole("WORKER"),
  upload.single("file"),
  handleMulterError,
  validate(uploadJobPhotoSchema),
  uploadJobPhotoHandler
);

uploadRouter.post(
  "/job-photo/confirm",
  requireAuth,
  requireRole("WORKER"),
  validate(confirmJobPhotoSchema),
  confirmJobPhotoHandler
);
