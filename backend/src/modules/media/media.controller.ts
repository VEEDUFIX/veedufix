import { Request, Response } from "express";
import {
  uploadAvatarImage,
  uploadWorkerDocumentImage,
  uploadWorkerPortfolioImage
} from "./media.service.js";

type RequestWithFile = Request & {
  file?: Express.Multer.File;
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
    sessionId: string;
  };
};

export async function uploadAvatarHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as RequestWithFile;
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  if (!authRequest.file) {
    response.status(400).json({ message: "Image file is required" });
    return;
  }

  const result = await uploadAvatarImage(authRequest.auth.userId, authRequest.file);
  response.status(200).json(result);
}

export async function uploadWorkerPortfolioHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as RequestWithFile;
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  if (!authRequest.file) {
    response.status(400).json({ message: "Image file is required" });
    return;
  }

  const caption = typeof request.body.caption === "string" ? request.body.caption : undefined;
  const result = await uploadWorkerPortfolioImage(authRequest.auth.userId, authRequest.file, caption);
  response.status(201).json(result);
}

export async function uploadWorkerDocumentHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as RequestWithFile;
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  if (!authRequest.file) {
    response.status(400).json({ message: "Image file is required" });
    return;
  }

  const type = typeof request.body.type === "string" ? request.body.type.trim() : "";
  if (!type) {
    response.status(400).json({ message: "Document type is required" });
    return;
  }

  const result = await uploadWorkerDocumentImage(authRequest.auth.userId, authRequest.file, type);
  response.status(201).json(result);
}
