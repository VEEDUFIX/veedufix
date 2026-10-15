import { Request, Response, NextFunction } from "express";
import { UserRole } from "@prisma/client";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import { AppError } from "../../lib/app-error.js";
import { deleteStagedBookingDiagnosticPhoto, getBookingDiagnosticPhotos, uploadBookingDiagnosticPhoto } from "./booking-diagnostic-photo.service.js";

type RequestWithPhoto = AuthenticatedRequest & { file?: Express.Multer.File };

export async function uploadBookingDiagnosticPhotoHandler(request: Request, response: Response, next: NextFunction): Promise<void> {
  try {
    const req = request as RequestWithPhoto;
    if (!req.file) throw AppError.badRequest("A photo file is required");
    const clientUploadId = typeof req.body?.clientUploadId === "string" ? req.body.clientUploadId : "";
    const photo = await uploadBookingDiagnosticPhoto({ userId: req.auth!.userId, clientUploadId, file: req.file });
    response.setHeader("Cache-Control", "private, no-store");
    response.status(201).json({ photo });
  } catch (error) { next(error); }
}

export async function deleteStagedBookingDiagnosticPhotoHandler(request: AuthenticatedRequest, response: Response, next: NextFunction): Promise<void> {
  try {
    await deleteStagedBookingDiagnosticPhoto(request.auth!.userId, String(request.params.photoId));
    response.status(204).end();
  } catch (error) { next(error); }
}

export async function getBookingDiagnosticPhotosHandler(request: AuthenticatedRequest, response: Response, next: NextFunction): Promise<void> {
  try {
    const photos = await getBookingDiagnosticPhotos({
      bookingId: String(request.params.bookingId),
      userId: request.auth!.userId,
      role: request.auth!.role as UserRole
    });
    response.setHeader("Cache-Control", "private, no-store");
    response.status(200).json({ photos });
  } catch (error) { next(error); }
}