import { Request, Response } from "express";
import { writeAuditLog } from "../../lib/audit.js";
import {
  BookingNotFoundError,
  DisputeAccessError,
  DisputeConflictError,
  DisputeNotFoundError,
  DisputeValidationError,
  DisputeWindowExpiredError,
  disputeService,
  getWorkerDispute,
  addDisputeMessage,
  updateDisputeClaim,
  proposeClaimReworkAppointment,
  completeClaimRework,
  confirmClaimResolution
} from "./dispute.service.js";

type AuthenticatedRequest = Request & {
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
    sessionId: string;
  };
};

function handleDisputeError(response: Response, error: unknown): boolean {
  if (error instanceof BookingNotFoundError) {
    response.status(404).json({ message: "Booking not found" });
    return true;
  }

  if (error instanceof DisputeNotFoundError) {
    response.status(404).json({ message: "Dispute not found" });
    return true;
  }

  if (error instanceof DisputeAccessError) {
    response.status(403).json({ message: "You are not allowed to perform this action" });
    return true;
  }

  if (error instanceof DisputeValidationError) {
    response.status(400).json({ message: error.message });
    return true;
  }

  if (error instanceof DisputeWindowExpiredError) {
    response.status(410).json({ message: "The dispute window has expired" });
    return true;
  }

  if (error instanceof DisputeConflictError) {
    response.status(409).json({ message: error.message });
    return true;
  }

  return false;
}

export async function raiseDisputeHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;

  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  try {
    const dispute = await disputeService.raiseDispute(
      String(request.params.bookingId),
      authRequest.auth.userId,
      request.body.reason,
      { issueCategory: request.body.issueCategory, serviceId: request.body.serviceId, evidencePhotoIds: request.body.evidencePhotoIds, idempotencyKey: request.body.idempotencyKey }
    );

    response.status(201).json(dispute);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}

export async function getWorkerDisputeHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as AuthenticatedRequest).auth;
  if (!auth) { response.status(401).json({ message: "Authentication required" }); return; }
  try {
    const dispute = await getWorkerDispute(String(request.params.bookingId), auth.userId);
    response.status(200).json(dispute);
  } catch (error) {
    if (!handleDisputeError(response, error)) throw error;
  }
}

export async function addDisputeMessageHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as AuthenticatedRequest).auth;
  if (!auth) { response.status(401).json({ message: "Authentication required" }); return; }
  try {
    const event = await addDisputeMessage({ bookingId: String(request.params.bookingId), userId: auth.userId, role: auth.role as "CUSTOMER" | "WORKER", message: request.body.message, idempotencyKey: request.body.idempotencyKey });
    response.status(201).json({ event });
  } catch (error) {
    if (!handleDisputeError(response, error)) throw error;
  }
}

export async function proposeClaimReworkHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as AuthenticatedRequest).auth;
  if (!auth) { response.status(401).json({ message: "Authentication required" }); return; }
  try {
    const result = await proposeClaimReworkAppointment({
      bookingId: String(request.params.bookingId), workerUserId: auth.userId,
      proposedAt: request.body.proposedAt, message: request.body.message,
      idempotencyKey: request.body.idempotencyKey
    });
    response.status(200).json({ dispute: result });
  } catch (error) {
    if (!handleDisputeError(response, error)) throw error;
  }
}

export async function completeClaimReworkHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as AuthenticatedRequest).auth;
  if (!auth) { response.status(401).json({ message: "Authentication required" }); return; }
  try {
    const result = await completeClaimRework({
      bookingId: String(request.params.bookingId), workerUserId: auth.userId,
      message: request.body.message, idempotencyKey: request.body.idempotencyKey
    });
    response.status(200).json({ dispute: result });
  } catch (error) {
    if (!handleDisputeError(response, error)) throw error;
  }
}

export async function confirmClaimResolutionHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as AuthenticatedRequest).auth;
  if (!auth) { response.status(401).json({ message: "Authentication required" }); return; }
  try {
    const result = await confirmClaimResolution({
      bookingId: String(request.params.bookingId), customerId: auth.userId,
      confirmed: request.body.confirmed, message: request.body.message,
      idempotencyKey: request.body.idempotencyKey
    });
    response.status(200).json({ dispute: result });
  } catch (error) {
    if (!handleDisputeError(response, error)) throw error;
  }
}

export async function updateDisputeClaimHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as AuthenticatedRequest).auth;
  if (!auth) { response.status(401).json({ message: "Authentication required" }); return; }
  try {
    const disputeId = String(request.params.disputeId);
    const result = await updateDisputeClaim({ disputeId, adminId: auth.userId, action: request.body.action, message: request.body.message, visibility: request.body.visibility, scheduledAt: request.body.scheduledAt });
    void writeAuditLog({
      adminId: auth.userId,
      action: "dispute.claim_updated",
      targetType: "dispute",
      targetId: disputeId,
      note: request.body.message,
      metadata: {
        claimAction: request.body.action,
        visibility: request.body.visibility ?? (request.body.action === "internal_note" ? "INTERNAL" : "CUSTOMER"),
        scheduledAt: request.body.scheduledAt instanceof Date
          ? request.body.scheduledAt.toISOString()
          : request.body.scheduledAt ?? null
      }
    });
    response.status(200).json(result);
  } catch (error) {
    if (!handleDisputeError(response, error)) throw error;
  }
}

export async function getCustomerDisputeHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  try {
    const result = await disputeService.getCustomerDispute(
      String(request.params.bookingId),
      authRequest.auth.userId
    );
    // The response envelope already includes `dispute`, `policy`, and
    // `canSubmit`; wrapping it again breaks the Customer app's parser.
    response.status(200).json(result);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}

export async function listDisputesHandler(request: Request, response: Response): Promise<void> {
  try {
    const result = await disputeService.listOpenDisputes({
      city: typeof request.query.city === "string" ? request.query.city : undefined,
      status: typeof request.query.status === "string"
        ? request.query.status as "all" | "open" | "under_review" | "refund_pending" | "action_required" | "approved" | "closed" | "resolved_rework" | "resolved_refund" | "resolved_rejected"
        : undefined,
      page:
        typeof request.query.page === "number" ? request.query.page : Number(request.query.page ?? 1),
      pageSize:
        typeof request.query.pageSize === "number" ? request.query.pageSize : Number(request.query.pageSize ?? 20)
    });

    response.status(200).json(result);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}

export async function getDisputeEvidenceHandler(request: Request, response: Response): Promise<void> {
  try {
    const result = await disputeService.getDisputeEvidence(String(request.params.disputeId));
    response.status(200).json(result);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}

export async function resolveDisputeHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;

  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  try {
    const disputeId = String(request.params.disputeId);
    const adminId = authRequest.auth.userId;
    const result = await disputeService.resolveDispute(
      disputeId,
      adminId,
      request.body.resolution,
      request.body.note
    );
    void writeAuditLog({
      adminId,
      action: "dispute.resolved",
      targetType: "dispute",
      targetId: disputeId,
      note: request.body.note,
      metadata: { resolution: request.body.resolution }
    });
    response.status(200).json(result);
  } catch (error) {
    if (!handleDisputeError(response, error)) {
      throw error;
    }
  }
}
