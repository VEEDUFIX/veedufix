import { describe, expect, it, vi } from "vitest";
import multer from "multer";
import type { NextFunction, Request, Response } from "express";
import {
  handleUploadError,
  UnsupportedDiagnosticPhotoTypeError
} from "../modules/media/booking-diagnostic-photo.routes.js";

function responseMocks() {
  const response = {
    status: vi.fn().mockReturnThis(),
    json: vi.fn()
  } as unknown as Response;
  const next = vi.fn() as unknown as NextFunction;
  return { response, next };
}

describe("booking diagnostic photo upload errors", () => {
  it("returns 400 for Multer errors and unsupported file types", () => {
    const cases = [
      [new multer.MulterError("LIMIT_FILE_SIZE"), "Image must be smaller than 10 MB"],
      [new multer.MulterError("LIMIT_UNEXPECTED_FILE"), "Invalid photo upload"],
      [new UnsupportedDiagnosticPhotoTypeError(), "Invalid photo upload"]
    ] as const;

    for (const [error, message] of cases) {
      const { response, next } = responseMocks();
      handleUploadError(error, {} as Request, response, next);
      expect(response.status).toHaveBeenCalledWith(400);
      expect(response.json).toHaveBeenCalledWith({ message });
      expect(next).not.toHaveBeenCalled();
    }
  });

  it("passes unrelated multipart and stream errors to the application error handler", () => {
    const error = new Error("multipart stream failed");
    const { response, next } = responseMocks();

    handleUploadError(error, {} as Request, response, next);

    expect(response.status).not.toHaveBeenCalled();
    expect(response.json).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledWith(error);
  });
});
