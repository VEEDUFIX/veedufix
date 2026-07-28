import { type NextFunction, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  IncompleteProfileError,
  WorkerProfileNotFoundError,
  WorkerStatusConflictError,
  addSkill,
  approveWorker,
  getAadhaarSignedUrl,
  getOnboardingStatus,
  getOwnAadhaarSignedUrl,
  getOwnSkillCertSignedUrl,
  getSkillCertSignedUrl,
  getWorkerDirectory,
  getWorkerHistory,
  listPendingReview,
  rejectWorker,
  reinstateWorker,
  submitForReview,
  suspendWorker,
  updatePersonalDetails,
  uploadDocument
} from "./worker-onboarding.service.js";

function sendError(response: Response, error: unknown): void {
  if (error instanceof IncompleteProfileError) {
    response.status(409).json({
      message: error.message,
      missingFields: error.missingFields
    });
    return;
  }

  if (error instanceof WorkerProfileNotFoundError) {
    response.status(404).json({ message: error.message });
    return;
  }

  if (error instanceof WorkerStatusConflictError) {
    response.status(409).json({ message: error.message });
    return;
  }

  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
    return;
  }

  response.status(500).json({ message: "Unexpected error" });
}

export async function updateProfileHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profile = await updatePersonalDetails(request.auth!.userId, request.body);
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function uploadDocumentHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profile = await uploadDocument(
      request.auth!.userId,
      request.body.docType,
      request.body.fileUrl,
      request.body.categoryId
    );
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function addSkillHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profile = await addSkill(request.auth!.userId, request.body.categoryId);
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function submitForReviewHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profile = await submitForReview(request.auth!.userId);
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function getStatusHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profile = await getOnboardingStatus(request.auth!.userId);
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function pendingReviewHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const result = await listPendingReview({
      page: request.query.page ? Number(request.query.page) : undefined,
      limit: request.query.limit ? Number(request.query.limit) : undefined,
      city: typeof request.query.city === "string" ? request.query.city : undefined,
      categoryId: typeof request.query.categoryId === "string" ? request.query.categoryId : undefined
    });

    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function approveWorkerHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profileId = String(request.params.profileId);
    const profile = await approveWorker(profileId, request.auth!.userId);
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function rejectWorkerHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profileId = String(request.params.profileId);
    const body = request.body as { reason: string };
    const profile = await rejectWorker(profileId, request.auth!.userId, body.reason);
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function suspendWorkerHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profileId = String(request.params.profileId);
    const body = request.body as { reason: string };
    const profile = await suspendWorker(profileId, request.auth!.userId, body.reason);
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function reinstateWorkerHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profileId = String(request.params.profileId);
    const body = request.body as { note: string };
    const profile = await reinstateWorker(profileId, request.auth!.userId, body.note);
    response.status(200).json({ profile });
  } catch (error) {
    sendError(response, error);
  }
}

export async function getWorkerDirectoryHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const result = await getWorkerDirectory({
      page: request.query.page ? Number(request.query.page) : undefined,
      limit: request.query.limit ? Number(request.query.limit) : undefined,
      city: typeof request.query.city === "string" ? request.query.city : undefined,
      categoryId: typeof request.query.categoryId === "string" ? request.query.categoryId : undefined,
      status: typeof request.query.status === "string" ? request.query.status : undefined
    });

    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function getWorkerHistoryHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profileId = String(request.params.profileId);
    const result = await getWorkerHistory(profileId);
    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

// ---------------------------------------------------------------------------
// KYC document access handlers
// Response shape: { url: string, expiresAt: string (ISO 8601) }
// ---------------------------------------------------------------------------

function kycDocResponse(response: Response, signedUrl: string, ttlSeconds = 300): void {
  const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();
  response.status(200).json({ url: signedUrl, expiresAt });
}

/** GET /api/worker/onboarding/documents/aadhaar  (WORKER — own document) */
export async function getOwnAadhaarDocHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const url = await getOwnAadhaarSignedUrl(request.auth!.userId);
    kycDocResponse(response, url);
  } catch (error) {
    sendError(response, error);
  }
}

/** GET /api/worker/onboarding/documents/skills/:skillId/certification  (WORKER — own) */
export async function getOwnSkillCertDocHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const skillId = String(request.params.skillId);
    const url = await getOwnSkillCertSignedUrl(request.auth!.userId, skillId);
    kycDocResponse(response, url);
  } catch (error) {
    sendError(response, error);
  }
}

/** GET /api/admin/worker-review/:profileId/documents/aadhaar  (ADMIN) */
export async function getAdminAadhaarDocHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profileId = String(request.params.profileId);
    const url = await getAadhaarSignedUrl(profileId);
    kycDocResponse(response, url);
  } catch (error) {
    sendError(response, error);
  }
}

/** GET /api/admin/worker-review/:profileId/documents/skills/:skillId/certification  (ADMIN) */
export async function getAdminSkillCertDocHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profileId = String(request.params.profileId);
    const skillId = String(request.params.skillId);
    const url = await getSkillCertSignedUrl(skillId, profileId);
    kycDocResponse(response, url);
  } catch (error) {
    sendError(response, error);
  }
}
