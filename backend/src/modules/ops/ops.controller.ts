import { type Request, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import { getOpsOverview, listOpsAlerts, updateOpsAlertStatus } from "./ops.service.js";

export async function getOpsOverviewHandler(_request: Request, response: Response): Promise<void> {
  const result = await getOpsOverview();
  response.status(200).json(result);
}

export async function getOpsAlertsHandler(request: Request, response: Response): Promise<void> {
  const result = await listOpsAlerts({
    type: typeof request.query.type === "string" ? request.query.type as any : undefined,
    severity: typeof request.query.severity === "string" ? request.query.severity as any : undefined,
    status: typeof request.query.status === "string" ? request.query.status as any : undefined,
    page: typeof request.query.page === "string" ? Number(request.query.page) : undefined,
    pageSize: typeof request.query.pageSize === "string" ? Number(request.query.pageSize) : undefined
  });

  response.status(200).json(result);
}

export async function updateOpsAlertStatusHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  const { alertId } = request.params;
  const body = request.body as { status: "open" | "acknowledged" | "resolved"; resolutionNote?: string };
  const alert = await updateOpsAlertStatus({
    alertId,
    status: body.status,
    resolutionNote: body.resolutionNote,
    adminId: request.auth!.userId
  });
  response.status(200).json(alert);
}
