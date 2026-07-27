import { Router } from "express";
import multer from "multer";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import {
  uploadAvatarHandler,
  uploadWorkerDocumentHandler,
  uploadWorkerPortfolioHandler
} from "./media.controller.js";

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024
  },
  fileFilter: (_request, file, callback) => {
    if (!file.mimetype.startsWith("image/")) {
      callback(new Error("Only image files are allowed"));
      return;
    }

    callback(null, true);
  }
});

export const mediaRouter = Router();

mediaRouter.post(
  "/avatar",
  requireAuth,
  upload.single("file"),
  uploadAvatarHandler
);

mediaRouter.post(
  "/workers/portfolio",
  requireAuth,
  requireRole("WORKER"),
  upload.single("file"),
  uploadWorkerPortfolioHandler
);

mediaRouter.post(
  "/workers/document",
  requireAuth,
  requireRole("WORKER"),
  upload.single("file"),
  uploadWorkerDocumentHandler
);
