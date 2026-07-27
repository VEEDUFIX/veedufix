import { Request, Response } from "express";
import {
  generateArrivalOtp,
  generateCompletionOtp,
  getArrivalOtpForCustomer,
  getCompletionOtpForCustomer,
  IncompleteJobError,
  OtpExpiredError,
  OtpInvalidError,
  UnauthorizedError,
  updateChecklist,
  uploadJobPhotos,
  verifyArrivalOtp,
  verifyCompletionOtp
} from "./job-execution.service.js";

type AuthenticatedRequest = Request & {
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
    sessionId: string;
  };
};

function handleKnownError(response: Response, error: unknown): boolean {
  if (error instanceof UnauthorizedError) {
    response.status(403).json({ message: error.message });
    return true;
  }

  if (error instanceof OtpExpiredError) {
    response.status(410).json({ message: error.message });
    return true;
  }

  if (error instanceof OtpInvalidError) {
    response.status(400).json({ message: error.message });
    return true;
  }

  if (error instanceof IncompleteJobError) {
    response.status(409).json({
      message: error.message,
      missingItems: error.missingItems,
      missingPhotos: error.missingPhotos
    });
    return true;
  }

  return false;
}

export async function arriveHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await generateArrivalOtp(String(request.params.bookingId), authRequest.auth!.userId, {
      workerLat: request.body.workerLat,
      workerLng: request.body.workerLng
    });
    response.status(200).json(result);
  } catch (error) {
    if (!handleKnownError(response, error)) {
      throw error;
    }
  }
}

export async function verifyArrivalOtpHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await verifyArrivalOtp(
      String(request.params.bookingId),
      authRequest.auth!.userId,
      request.body.otpInput
    );
    response.status(200).json(result);
  } catch (error) {
    if (!handleKnownError(response, error)) {
      throw error;
    }
  }
}

export async function getArrivalOtpHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await getArrivalOtpForCustomer(String(request.params.bookingId), authRequest.auth!.userId);
    response.status(200).json(result);
  } catch (error) {
    if (!handleKnownError(response, error)) {
      throw error;
    }
  }
}

export async function photosHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await uploadJobPhotos(
      String(request.params.bookingId),
      authRequest.auth!.userId,
      request.body.photoUrls,
      request.body.type
    );
    response.status(200).json(result);
  } catch (error) {
    if (!handleKnownError(response, error)) {
      throw error;
    }
  }
}

export async function checklistHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await updateChecklist(
      String(request.params.bookingId),
      authRequest.auth!.userId,
      request.body.items
    );
    response.status(200).json(result);
  } catch (error) {
    if (!handleKnownError(response, error)) {
      throw error;
    }
  }
}

export async function requestCompletionOtpHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await generateCompletionOtp(String(request.params.bookingId), authRequest.auth!.userId);
    response.status(200).json(result);
  } catch (error) {
    if (!handleKnownError(response, error)) {
      throw error;
    }
  }
}

export async function getCompletionOtpHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await getCompletionOtpForCustomer(
      String(request.params.bookingId),
      authRequest.auth!.userId
    );
    response.status(200).json(result);
  } catch (error) {
    if (!handleKnownError(response, error)) {
      throw error;
    }
  }
}

export async function verifyCompletionOtpHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  try {
    const result = await verifyCompletionOtp(
      String(request.params.bookingId),
      authRequest.auth!.userId,
      request.body.otpInput
    );
    response.status(200).json(result);
  } catch (error) {
    if (!handleKnownError(response, error)) {
      throw error;
    }
  }
}
