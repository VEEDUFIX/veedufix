import { Request, Response } from "express";
import {
  uploadAvatarImage,
  uploadWorkerDocumentImage,
  uploadWorkerPortfolioImage
} from "./media.service.js";
import type { DocumentType } from "./media.schemas.js";

type RequestWithFile = Request & {
  file?: Express.Multer.File;
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
    sessionId: string;
  };
};

function sendMediaError(response: Response, error: unknown): void {
  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
    return;
  }
  response.status(500).json({ message: "Unexpected error" });
}

// ---------------------------------------------------------------------------
// POST /api/media/avatar
// Expects: multipart/form-data with a single "file" field (image/jpeg or
// image/png, max 10 MB — enforced by multer in media.routes.ts).
// Body fields: none required.
// ---------------------------------------------------------------------------
export async function uploadAvatarHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as RequestWithFile;
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  // File presence is a multipart concern — multer populates req.file, not req.body,
  // so it cannot be expressed in a Zod body schema. Guard it explicitly here.
  if (!authRequest.file) {
    response.status(400).json({ message: "A file is required (field name: file)" });
    return;
  }

  try {
    const result = await uploadAvatarImage(authRequest.auth.userId, authRequest.file);
    response.status(200).json(result);
  } catch (error) {
    sendMediaError(response, error);
  }
}

// ---------------------------------------------------------------------------
// POST /api/media/workers/portfolio
// Expects: multipart/form-data with a single "file" field (image/jpeg or
// image/png, max 10 MB — enforced by multer in media.routes.ts).
// Body fields: caption? (string, max 200 chars) — validated by portfolioUploadSchema.
// ---------------------------------------------------------------------------
export async function uploadWorkerPortfolioHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as RequestWithFile;
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  if (!authRequest.file) {
    response.status(400).json({ message: "A file is required (field name: file)" });
    return;
  }

  // request.body is already parsed and typed by the validate(portfolioUploadSchema)
  // middleware that runs before this handler.
  const caption = typeof request.body?.caption === "string" ? request.body.caption : undefined;

  try {
    const result = await uploadWorkerPortfolioImage(authRequest.auth.userId, authRequest.file, caption);
    response.status(201).json(result);
  } catch (error) {
    sendMediaError(response, error);
  }
}

// ---------------------------------------------------------------------------
// POST /api/media/workers/document
// Expects: multipart/form-data with a single "file" field (image/jpeg or
// image/png, max 10 MB — enforced by multer in media.routes.ts).
// Body fields: type (required enum) — validated by documentUploadSchema.
// ---------------------------------------------------------------------------
export async function uploadWorkerDocumentHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as RequestWithFile;
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  if (!authRequest.file) {
    response.status(400).json({ message: "A file is required (field name: file)" });
    return;
  }

  // request.body.type is guaranteed to be a valid DocumentType enum value here
  // because validate(documentUploadSchema) runs before this handler and would
  // have short-circuited with a 400 if the field were missing or invalid.
  const type = request.body.type as DocumentType;

  try {
    const result = await uploadWorkerDocumentImage(authRequest.auth.userId, authRequest.file, type);
    response.status(201).json(result);
  } catch (error) {
    sendMediaError(response, error);
  }
}
