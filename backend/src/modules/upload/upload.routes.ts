import { Router } from "express";
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
      callback(new Error("Only JPEG and PNG images are allowed"));
      return;
    }

    callback(null, true);
  }
});

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
