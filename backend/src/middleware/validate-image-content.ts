import { NextFunction, Request, Response } from "express";

export function validateImageContent(request: Request, response: Response, next: NextFunction): void {
  const file = (request as Request & { file?: Express.Multer.File }).file;
  if (!file) {
    next();
    return;
  }

  const bytes = file.buffer;
  const isPng = file.mimetype === "image/png" &&
    bytes.length >= 8 &&
    bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  const isJpeg = file.mimetype === "image/jpeg" &&
    bytes.length >= 3 &&
    bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;

  if (!isPng && !isJpeg) {
    response.status(400).json({ message: "The uploaded file is not a valid JPEG or PNG image." });
    return;
  }

  next();
}
