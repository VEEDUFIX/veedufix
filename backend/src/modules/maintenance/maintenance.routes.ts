import { Router } from "express";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  createMaintenancePlanSchema,
  adminMaintenancePlansQuerySchema,
  maintenanceOccurrenceParamsSchema,
  maintenancePlanParamsSchema,
  rescheduleMaintenanceOccurrenceSchema
} from "./maintenance.schemas.js";
import {
  createCustomerMaintenancePlan,
  listAdminMaintenancePlans,
  listCustomerMaintenancePlans,
  updateCustomerMaintenanceOccurrence,
  updateCustomerMaintenancePlan
} from "./maintenance.service.js";

export const maintenanceRouter = Router();
const customerOnly = [requireAuth, requireRole("CUSTOMER")] as const;

maintenanceRouter.get("/admin", requireAuth, requireRole("ADMIN"), validate(adminMaintenancePlansQuerySchema), async (request, response) => {
  const status = typeof request.query.status === "string" ? request.query.status : undefined;
  const serviceId = typeof request.query.serviceId === "string" ? request.query.serviceId : undefined;
  const plans = await listAdminMaintenancePlans({ status, serviceId });
  response.status(200).json({ plans });
});

maintenanceRouter.get("/", ...customerOnly, async (request: AuthenticatedRequest, response) => {
  const plans = await listCustomerMaintenancePlans(request.auth!.userId);
  response.status(200).json({ plans });
});

maintenanceRouter.post("/", ...customerOnly, validate(createMaintenancePlanSchema), async (request: AuthenticatedRequest, response) => {
  const plan = await createCustomerMaintenancePlan(request.auth!.userId, request.body);
  response.status(201).json({ plan });
});

maintenanceRouter.post("/:planId/pause", ...customerOnly, validate(maintenancePlanParamsSchema), async (request: AuthenticatedRequest, response) => {
  const plan = await updateCustomerMaintenancePlan(request.auth!.userId, String(request.params.planId), "pause");
  response.status(200).json({ plan });
});

maintenanceRouter.post("/:planId/resume", ...customerOnly, validate(maintenancePlanParamsSchema), async (request: AuthenticatedRequest, response) => {
  const plan = await updateCustomerMaintenancePlan(request.auth!.userId, String(request.params.planId), "resume");
  response.status(200).json({ plan });
});

maintenanceRouter.post("/:planId/cancel", ...customerOnly, validate(maintenancePlanParamsSchema), async (request: AuthenticatedRequest, response) => {
  const plan = await updateCustomerMaintenancePlan(request.auth!.userId, String(request.params.planId), "cancel");
  response.status(200).json({ plan });
});

maintenanceRouter.post("/:planId/occurrences/:occurrenceId/skip", ...customerOnly, validate(maintenanceOccurrenceParamsSchema), async (request: AuthenticatedRequest, response) => {
  const plan = await updateCustomerMaintenanceOccurrence({ customerId: request.auth!.userId, planId: String(request.params.planId), occurrenceId: String(request.params.occurrenceId), action: "skip" });
  response.status(200).json({ plan });
});

maintenanceRouter.post("/:planId/occurrences/:occurrenceId/reschedule", ...customerOnly, validate(rescheduleMaintenanceOccurrenceSchema), async (request: AuthenticatedRequest, response) => {
  const plan = await updateCustomerMaintenanceOccurrence({ customerId: request.auth!.userId, planId: String(request.params.planId), occurrenceId: String(request.params.occurrenceId), action: "reschedule", dueAt: request.body.dueAt });
  response.status(200).json({ plan });
});
