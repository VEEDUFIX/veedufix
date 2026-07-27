import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  disputeIdParamsOnlySchema,
  listDisputesQuerySchema,
  raiseDisputeSchema,
  resolveDisputeSchema
} from "./dispute.schemas.js";
import {
  getDisputeEvidenceHandler,
  listDisputesHandler,
  raiseDisputeHandler,
  resolveDisputeHandler
} from "./dispute.controller.js";

export const disputeRouter = Router();

const customerOnly = [requireAuth, requireRole("CUSTOMER")] as const;
const adminOnly = [requireAuth, requireRole("ADMIN")] as const;

disputeRouter.post(
  "/bookings/:bookingId/dispute",
  ...customerOnly,
  validate(raiseDisputeSchema),
  raiseDisputeHandler
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
