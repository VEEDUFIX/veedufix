import { type Request, type Response } from "express";
import { getOpsOverview, listOpsAlerts } from "./ops.service.js";

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
