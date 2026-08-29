import { Request, Response } from "express";
import {
  assertWorkerCanUploadJobPhoto,
  uploadChatAttachment,
  confirmJobPhotoUpload,
  generateUploadSignature,
  uploadAndRecordJobPhoto
} from "./upload.service.js";

type UploadRequest = Request & {
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
  sessionId: string;
  };
  file?: Express.Multer.File;
};

export async function uploadChatAttachmentHandler(request: Request, response: Response): Promise<void> {
  const uploadRequest = request as UploadRequest;
  if (!uploadRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  if (!uploadRequest.file) {
    response.status(400).json({ message: "Image file is required" });
    return;
  }

  const bookingId = String(request.body.bookingId ?? "").trim();
  if (!bookingId) {
    response.status(400).json({ message: "bookingId is required" });
    return;
  }

  const result = await uploadChatAttachment(
    uploadRequest.file.buffer,
    bookingId,
    uploadRequest.auth.userId,
    uploadRequest.file.originalname
  );

  response.status(201).json({
    attachment: {
      url: result.secureUrl,
      name: uploadRequest.file.originalname,
      mimeType: uploadRequest.file.mimetype,
      size: result.bytes,
      kind: "image",
      publicId: result.publicId,
      folder: result.folder,
      format: result.format ?? null
    }
  });
}

export async function generateUploadSignatureHandler(
  request: Request,
  response: Response
): Promise<void> {
  const uploadRequest = request as UploadRequest;
  if (!uploadRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  const bookingId = String(request.body.bookingId);
  const type = String(request.body.type) as "before" | "after";

  await assertWorkerCanUploadJobPhoto(bookingId, uploadRequest.auth.userId);

  const signature = await generateUploadSignature(bookingId, type);
  response.status(200).json(signature);
}

export async function uploadJobPhotoHandler(request: Request, response: Response): Promise<void> {
  const uploadRequest = request as UploadRequest;
  if (!uploadRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  if (!uploadRequest.file) {
    response.status(400).json({ message: "Image file is required" });
    return;
  }

  const bookingId = String(request.body.bookingId ?? "").trim();
  const type = String(request.body.type ?? "").trim() as "before" | "after";

  if (!bookingId || !type) {
    response.status(400).json({ message: "bookingId and type are required" });
    return;
  }

  await assertWorkerCanUploadJobPhoto(bookingId, uploadRequest.auth.userId);

  const result = await uploadAndRecordJobPhoto(
    uploadRequest.file.buffer,
    bookingId,
    uploadRequest.auth.userId,
    type
  );
  response.status(201).json(result);
}

export async function confirmJobPhotoHandler(request: Request, response: Response): Promise<void> {
  const uploadRequest = request as UploadRequest;
  if (!uploadRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  const bookingId = String(request.body.bookingId ?? "").trim();
  const type = String(request.body.type ?? "").trim() as "before" | "after";
  const secureUrl = String(request.body.secureUrl ?? "").trim();
  const publicId = String(request.body.publicId ?? "").trim();
  const folder = typeof request.body.folder === "string" ? request.body.folder.trim() : undefined;
  const bytes = typeof request.body.bytes === "number" ? request.body.bytes : Number(request.body.bytes);
  const format = typeof request.body.format === "string" ? request.body.format.trim() : undefined;

  if (!bookingId || !type || !secureUrl || !publicId) {
    response.status(400).json({ message: "bookingId, type, secureUrl, and publicId are required" });
    return;
  }

  await assertWorkerCanUploadJobPhoto(bookingId, uploadRequest.auth.userId);

  const result = await confirmJobPhotoUpload(bookingId, uploadRequest.auth.userId, type, {
    secureUrl,
    publicId,
    bytes: Number.isFinite(bytes) ? bytes : 0,
    format
  });

  response.status(201).json({
    ...result,
    folder: folder ?? result.notification.photoFolder
  });
}
