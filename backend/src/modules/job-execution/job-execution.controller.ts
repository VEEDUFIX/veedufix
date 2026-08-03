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
    response.status(403).json({ message: "You are not authorized to perform this action" });
    return true;
  }

  if (error instanceof OtpExpiredError) {
    response.status(410).json({ message: "The OTP has expired" });
    return true;
  }

  if (error instanceof OtpInvalidError) {
    response.status(400).json({ message: "Invalid OTP" });
    return true;
  }

  if (error instanceof IncompleteJobError) {
    response.status(409).json({
      message: "Job is incomplete",
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
      response.status(400).json({ message: "Unable to process arrival request" });
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
      response.status(400).json({ message: "Unable to verify arrival OTP" });
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
      response.status(400).json({ message: "Unable to load arrival OTP" });
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
      response.status(400).json({ message: "Unable to upload job photos" });
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
      response.status(400).json({ message: "Unable to update checklist" });
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
      response.status(400).json({ message: "Unable to request completion OTP" });
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
      response.status(400).json({ message: "Unable to load completion OTP" });
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
      response.status(400).json({ message: "Unable to verify completion OTP" });
    }
  }
}
