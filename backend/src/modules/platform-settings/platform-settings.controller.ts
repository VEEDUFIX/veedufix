import { type Request, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  deleteCommission,
  getPlatformSettings,
  listCommissions,
  listPlatformSettingsHistory,
  saveCommission,
  savePlatformSettings
} from "./platform-settings.service.js";

export async function getPlatformSettingsHandler(_request: Request, response: Response): Promise<void> {
  const result = await getPlatformSettings();
  response.status(200).json(result);
}

export async function savePlatformSettingsHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  const result = await savePlatformSettings(
    request.body as Record<string, unknown>,
    authRequest.auth?.userId
  );
  response.status(200).json(result);
}

export async function listCommissionsHandler(_request: Request, response: Response): Promise<void> {
  const result = await listCommissions();
  response.status(200).json(result);
}

export async function saveCommissionHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  const commissionId = typeof request.params.commissionId === "string" ? request.params.commissionId : null;

  const result = await saveCommission(
    commissionId,
    request.body as Record<string, unknown>,
    authRequest.auth?.userId
  );
  response.status(200).json(result);
}

export async function deleteCommissionHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as AuthenticatedRequest;
  const commissionId = typeof request.params.commissionId === "string" ? request.params.commissionId : null;

  if (!commissionId) {
    response.status(400).json({ error: "commissionId is required" });
    return;
  }

  await deleteCommission(commissionId, authRequest.auth?.userId);
  response.status(200).json({ success: true });
}

export async function listPlatformSettingsHistoryHandler(_request: Request, response: Response): Promise<void> {
  const result = await listPlatformSettingsHistory();
  response.status(200).json(result);
}
