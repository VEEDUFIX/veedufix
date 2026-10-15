import { beforeEach, describe, expect, it, vi } from "vitest";

const { getCustomerDispute, raiseDispute, updateDisputeClaim, writeAuditLog, DisputeConflictError, DisputeValidationError } = vi.hoisted(() => ({
  getCustomerDispute: vi.fn(),
  raiseDispute: vi.fn(),
  updateDisputeClaim: vi.fn(),
  writeAuditLog: vi.fn(),
  DisputeConflictError: class DisputeConflictError extends Error {},
  DisputeValidationError: class DisputeValidationError extends Error {}
}));

vi.mock("../modules/dispute/dispute.service.js", () => ({
  disputeService: { getCustomerDispute, raiseDispute },
  BookingNotFoundError: class BookingNotFoundError extends Error {},
  DisputeAccessError: class DisputeAccessError extends Error {},
  DisputeConflictError,
  DisputeValidationError,
  DisputeNotFoundError: class DisputeNotFoundError extends Error {},
  DisputeWindowExpiredError: class DisputeWindowExpiredError extends Error {},
  getWorkerDispute: vi.fn(),
  addDisputeMessage: vi.fn(),
  updateDisputeClaim,
}));

vi.mock("../lib/audit.js", () => ({ writeAuditLog }));

import {
  getCustomerDisputeHandler,
  raiseDisputeHandler,
  updateDisputeClaimHandler
} from "../modules/dispute/dispute.controller.js";

describe("getCustomerDisputeHandler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns the flat dispute, policy, and eligibility envelope expected by the apps", async () => {
    const result = {
      dispute: { id: "claim-1", status: "open" },
      policy: { enabled: true, issueCategories: ["damage"] },
      canSubmit: false,
      legacyWindow: false,
    };
    getCustomerDispute.mockResolvedValue(result);
    const response = { status: vi.fn().mockReturnThis(), json: vi.fn() };

    await getCustomerDisputeHandler({
      params: { bookingId: "booking-1" },
      auth: { userId: "customer-1", role: "CUSTOMER", sessionId: "session-1" },
    } as never, response as never);

    expect(response.status).toHaveBeenCalledWith(200);
    expect(response.json).toHaveBeenCalledWith(result);
    expect(response.json.mock.calls[0][0]).not.toHaveProperty("dispute.dispute");
  });

  it("returns specific validation and conflict messages from claim services", async () => {
    const response = () => ({ status: vi.fn().mockReturnThis(), json: vi.fn() });
    const request = () => ({
      params: { bookingId: "booking-1" },
      body: { reason: "damage" },
      auth: { userId: "customer-1", role: "CUSTOMER", sessionId: "session-1" }
    });

    raiseDispute.mockRejectedValueOnce(new DisputeValidationError("Select a booked service"));
    const validationResponse = response();
    await raiseDisputeHandler(request() as never, validationResponse as never);
    expect(validationResponse.status).toHaveBeenCalledWith(400);
    expect(validationResponse.json).toHaveBeenCalledWith({ message: "Select a booked service" });

    raiseDispute.mockRejectedValueOnce(new DisputeConflictError("The claim is closed"));
    const conflictResponse = response();
    await raiseDisputeHandler(request() as never, conflictResponse as never);
    expect(conflictResponse.status).toHaveBeenCalledWith(409);
    expect(conflictResponse.json).toHaveBeenCalledWith({ message: "The claim is closed" });
  });
});

describe("updateDisputeClaimHandler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("writes an audit record after a successful Admin claim action", async () => {
    const result = { id: "claim-1", status: "resolved_rejected" };
    updateDisputeClaim.mockResolvedValue(result);
    const response = { status: vi.fn().mockReturnThis(), json: vi.fn() };

    await updateDisputeClaimHandler({
      params: { disputeId: "claim-1" },
      body: {
        action: "reject",
        message: "The claim is not covered.",
      },
      auth: { userId: "admin-1", role: "ADMIN", sessionId: "session-1" },
    } as never, response as never);

    expect(response.status).toHaveBeenCalledWith(200);
    expect(response.json).toHaveBeenCalledWith(result);
    expect(writeAuditLog).toHaveBeenCalledWith({
      adminId: "admin-1",
      action: "dispute.claim_updated",
      targetType: "dispute",
      targetId: "claim-1",
      note: "The claim is not covered.",
      metadata: {
        claimAction: "reject",
        visibility: "CUSTOMER",
        scheduledAt: null,
      },
    });
  });
});
