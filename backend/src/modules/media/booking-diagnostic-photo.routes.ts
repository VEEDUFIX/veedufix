import { NextFunction, Request, Response, Router } from "express";
import multer from "multer";
import { z } from "zod";
import { AuthenticatedRequest, requireAuth } from "../../middleware/auth.js";
import { validateImageContent } from "../../middleware/validate-image-content.js";
import { AppError } from "../../lib/app-error.js";
import { deleteStagedBookingDiagnosticPhotoHandler, getBookingDiagnosticPhotosHandler, uploadBookingDiagnosticPhotoHandler } from "./booking-diagnostic-photo.controller.js";

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 1 },
  fileFilter: (_request, file, callback) => {
    if (file.mimetype !== "image/jpeg" && file.mimetype !== "image/png") {
      callback(new UnsupportedDiagnosticPhotoTypeError());
      return;
    }
    callback(null, true);
  }
});

export class UnsupportedDiagnosticPhotoTypeError extends Error {
  constructor() {
    super("Only JPEG and PNG images are supported");
    this.name = "UnsupportedDiagnosticPhotoTypeError";
  }
}

export function handleUploadError(error: unknown, _request: Request, response: Response, next: NextFunction): void {
  if (error instanceof multer.MulterError) {
    response.status(400).json({
      message: error.code === "LIMIT_FILE_SIZE"
        ? "Image must be smaller than 10 MB"
        : "Invalid photo upload"
    });
    return;
  }
  if (error instanceof UnsupportedDiagnosticPhotoTypeError) {
    response.status(400).json({ message: "Invalid photo upload" });
    return;
  }
  next(error);
}

const uploadIdSchema = z.string().trim().min(1).max(120);
function requireCustomer(request: AuthenticatedRequest, response: Response, next: NextFunction): void {
  if (request.auth?.role !== "CUSTOMER") {
    response.status(request.auth ? 403 : 401).json({ message: "Customer access required" });
    return;
  }
  next();
}
export const bookingDiagnosticPhotoUploadRouter = Router();
bookingDiagnosticPhotoUploadRouter.post("/booking-diagnostic-photos", requireAuth, requireCustomer, upload.single("file"), handleUploadError, validateImageContent, (request: AuthenticatedRequest, response: Response, next: NextFunction) => {
  if (!request.file) {
    next(AppError.badRequest("A photo file is required"));
    return;
  }
  const id = request.body?.clientUploadId;
  const parsed = uploadIdSchema.safeParse(id);
  if (!parsed.success) {
    next(AppError.badRequest("A valid clientUploadId is required"));
    return;
  }
  void uploadBookingDiagnosticPhotoHandler(request, response, next);
});
bookingDiagnosticPhotoUploadRouter.delete("/booking-diagnostic-photos/:photoId", requireAuth, requireCustomer, (request: AuthenticatedRequest, response, next) => {
  void deleteStagedBookingDiagnosticPhotoHandler(request, response, next);
});

export const bookingDiagnosticPhotosRouter = Router();
bookingDiagnosticPhotosRouter.get("/bookings/:bookingId/diagnostic-photos", requireAuth, getBookingDiagnosticPhotosHandler);
