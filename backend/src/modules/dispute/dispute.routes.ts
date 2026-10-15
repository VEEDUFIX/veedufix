import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  customerDisputeParamsSchema,
  disputeIdParamsOnlySchema,
  listDisputesQuerySchema,
  claimMessageSchema,
  raiseDisputeSchema,
  resolveDisputeSchema,
  updateDisputeClaimSchema,
  claimReworkProposalSchema,
  claimReworkCompletionSchema,
  claimResolutionConfirmationSchema
} from "./dispute.schemas.js";
import {
  getDisputeEvidenceHandler,
  getCustomerDisputeHandler,
  listDisputesHandler,
  raiseDisputeHandler,
  resolveDisputeHandler,
  getWorkerDisputeHandler,
  addDisputeMessageHandler,
  updateDisputeClaimHandler,
  proposeClaimReworkHandler,
  completeClaimReworkHandler,
  confirmClaimResolutionHandler
} from "./dispute.controller.js";

export const disputeRouter = Router();

const customerOnly = [requireAuth, requireRole("CUSTOMER")] as const;
const adminOnly = [requireAuth, requireRole("ADMIN")] as const;
const customerOrWorker = [requireAuth, requireRole("CUSTOMER", "WORKER")] as const;

disputeRouter.post(
  "/bookings/:bookingId/dispute",
  ...customerOnly,
  validate(raiseDisputeSchema),
  raiseDisputeHandler
);

disputeRouter.get(
  "/bookings/:bookingId/dispute",
  ...customerOnly,
  validate(customerDisputeParamsSchema),
  getCustomerDisputeHandler
);

disputeRouter.get(
  "/worker/bookings/:bookingId/dispute",
  requireAuth,
  requireRole("WORKER"),
  validate(customerDisputeParamsSchema),
  getWorkerDisputeHandler
);
disputeRouter.post(
  "/bookings/:bookingId/dispute/message",
  ...customerOrWorker,
  validate(claimMessageSchema),
  addDisputeMessageHandler
);
disputeRouter.post(
  "/bookings/:bookingId/dispute/confirm",
  ...customerOnly,
  validate(claimResolutionConfirmationSchema),
  confirmClaimResolutionHandler
);
disputeRouter.post(
  "/worker/bookings/:bookingId/dispute/rework/propose",
  requireAuth,
  requireRole("WORKER"),
  validate(claimReworkProposalSchema),
  proposeClaimReworkHandler
);
disputeRouter.post(
  "/worker/bookings/:bookingId/dispute/rework/complete",
  requireAuth,
  requireRole("WORKER"),
  validate(claimReworkCompletionSchema),
  completeClaimReworkHandler
);

disputeRouter.get(
  "/admin/disputes",
  ...adminOnly,
  validate(listDisputesQuerySchema),
  listDisputesHandler
);

disputeRouter.get(
  "/admin/disputes/:disputeId",
  ...adminOnly,
  validate(disputeIdParamsOnlySchema),
  getDisputeEvidenceHandler
);

disputeRouter.post(
  "/admin/disputes/:disputeId/resolve",
  ...adminOnly,
  validate(resolveDisputeSchema),
  resolveDisputeHandler
);

disputeRouter.post(
  "/admin/disputes/:disputeId/update",
  ...adminOnly,
  validate(updateDisputeClaimSchema),
  updateDisputeClaimHandler
);
