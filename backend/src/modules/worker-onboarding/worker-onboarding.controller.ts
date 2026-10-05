import { type NextFunction, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import { writeAuditLog } from "../../lib/audit.js";
import {
  IncompleteProfileError,
  WorkerProfileNotFoundError,
  WorkerStatusConflictError,
  addSkill,
  addService,
  approvePayoutChangeRequest,
  approveWorker,
  getAadhaarSignedUrl,
  getOnboardingStatus,
  getMyPayoutChangeRequest,
  getOwnAadhaarSignedUrl,
  getOwnSkillCertSignedUrl,
  getWorkerReviewProfile,
  getSkillCertSignedUrl,
  getWorkerDirectory,
  getWorkerHistory,
  listPendingReview,
  listPayoutChangeRequests,
  rejectWorker,
  rejectPayoutChangeRequest,
  reinstateWorker,
  submitForReview,
  submitPayoutChangeRequest,
  suspendWorker,
  updatePersonalDetails,
  uploadDocument
} from "./worker-onboarding.service.js";

function sendError(response: Response, error: unknown): void {
  if (error instanceof IncompleteProfileError) {
    response.status(409).json({
      message: "Worker profile is incomplete",
      missingFields: error.missingFields
    });
    return;
  }

  if (error instanceof WorkerProfileNotFoundError) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  if (error instanceof WorkerStatusConflictError) {
    response.status(409).json({ message: error.message });
    return;
  }

  if (error instanceof Error) {
    response.status(400).json({ message: "Unable to process worker onboarding request" });
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

export async function getMyPayoutChangeRequestHandler(request: AuthenticatedRequest, response: Response) {
  try {
    response.status(200).json(await getMyPayoutChangeRequest(request.auth!.userId));
  } catch (error) {
    sendError(response, error);
  }
}

export async function submitPayoutChangeRequestHandler(request: AuthenticatedRequest, response: Response) {
  try {
    response.status(201).json(await submitPayoutChangeRequest(request.auth!.userId, request.body));
  } catch (error) {
    sendError(response, error);
  }
}

export async function pendingPayoutChangeRequestsHandler(_request: AuthenticatedRequest, response: Response) {
  try {
    response.status(200).json(await listPayoutChangeRequests());
  } catch (error) {
    sendError(response, error);
  }
}

export async function approvePayoutChangeRequestHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const requestId = String(request.params.requestId);
    const adminId = request.auth!.userId;
    const result = await approvePayoutChangeRequest(requestId, adminId);
    void writeAuditLog({ adminId, action: "worker.payout_change_approved", targetType: "worker_payout_change_request", targetId: requestId });
    const target = await prisma.workerProfile.findUnique({ where: { id: result.workerProfileId }, select: { userId: true } });
    if (target) void publishNotificationEvent({
      userId: target.userId,
      title: "Payout account updated",
      body: "Your new payout details have been approved.",
      type: "WORKER_PAYOUT_CHANGE_APPROVED",
      data: { route: "/profile/payment-details", payoutChangeRequestId: requestId }
    });
    response.status(200).json({ request: { id: requestId, status: "approved" } });
  } catch (error) {
    sendError(response, error);
  }
}

export async function rejectPayoutChangeRequestHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const requestId = String(request.params.requestId);
    const adminId = request.auth!.userId;
    const reason = (request.body as { reason: string }).reason;
    await rejectPayoutChangeRequest(requestId, adminId, reason);
    void writeAuditLog({ adminId, action: "worker.payout_change_rejected", targetType: "worker_payout_change_request", targetId: requestId, note: reason });
    response.status(200).json({ request: { id: requestId, status: "rejected", rejectionReason: reason } });
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

export async function addServiceHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profile = await addService(request.auth!.userId, request.body.serviceId);
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

export async function workerReviewDetailHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
) {
  try {
    const profileId = String(request.params.profileId);
    const profile = await getWorkerReviewProfile(profileId);
    response.status(200).json({ profile });
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
    const adminId = request.auth!.userId;
    const target = await prisma.workerProfile.findUnique({
      where: { id: profileId },
      select: { userId: true, fullName: true }
    });
    const profile = await approveWorker(profileId, adminId);
    void writeAuditLog({ adminId, action: "worker.approved", targetType: "worker_profile", targetId: profileId });
    if (target) {
      void publishNotificationEvent({
        userId: target.userId,
        title: "Onboarding approved",
        body: "Your worker profile has been approved. You can start receiving jobs.",
        type: "WORKER_ONBOARDING_APPROVED",
        data: {
          profileId,
          fullName: target.fullName,
          route: "/worker",
          onboardingStatus: "approved"
        }
      });
    }
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
    const adminId = request.auth!.userId;
    const body = request.body as { reason: string };
    const target = await prisma.workerProfile.findUnique({
      where: { id: profileId },
      select: { userId: true, fullName: true }
    });
    const profile = await rejectWorker(profileId, adminId, body.reason);
    void writeAuditLog({ adminId, action: "worker.rejected", targetType: "worker_profile", targetId: profileId, note: body.reason });
    if (target) {
      void publishNotificationEvent({
        userId: target.userId,
        title: "Onboarding needs changes",
        body: body.reason || "Please review the feedback and resubmit your profile.",
        type: "WORKER_ONBOARDING_REJECTED",
        data: {
          profileId,
          fullName: target.fullName,
          route: "/onboarding/status",
          onboardingStatus: "rejected"
        }
      });
    }
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
    const adminId = request.auth!.userId;
    const body = request.body as { reason: string };
    const target = await prisma.workerProfile.findUnique({
      where: { id: profileId },
      select: { userId: true, fullName: true }
    });
    const profile = await suspendWorker(profileId, adminId, body.reason);
    void writeAuditLog({ adminId, action: "worker.suspended", targetType: "worker_profile", targetId: profileId, note: body.reason });
    if (target) {
      void publishNotificationEvent({
        userId: target.userId,
        title: "Account suspended",
        body: body.reason || "Please contact support for more details.",
        type: "WORKER_ONBOARDING_SUSPENDED",
        data: {
          profileId,
          fullName: target.fullName,
          route: "/onboarding/status",
          onboardingStatus: "suspended"
        }
      });
    }
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
    const adminId = request.auth!.userId;
    const body = request.body as { note: string };
    const target = await prisma.workerProfile.findUnique({
      where: { id: profileId },
      select: { userId: true, fullName: true }
    });
    const profile = await reinstateWorker(profileId, adminId, body.note);
    void writeAuditLog({ adminId, action: "worker.reinstated", targetType: "worker_profile", targetId: profileId, note: body.note });
    if (target) {
      void publishNotificationEvent({
        userId: target.userId,
        title: "Account reinstated",
        body: body.note || "Your worker account is active again.",
        type: "WORKER_ONBOARDING_REINSTATED",
        data: {
          profileId,
          fullName: target.fullName,
          route: "/worker",
          onboardingStatus: "approved"
        }
      });
    }
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
      status: typeof request.query.status === "string" ? request.query.status : undefined,
      search: typeof request.query.search === "string" ? request.query.search : undefined
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
  response.setHeader("Cache-Control", "private, no-store");
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
