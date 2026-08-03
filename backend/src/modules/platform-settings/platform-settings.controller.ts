import { type Request, type Response } from "express";
import {
  deleteCommission,
  getPlatformSettings,
  listCommissions,
  saveCommission,
  savePlatformSettings
} from "./platform-settings.service.js";

export async function getPlatformSettingsHandler(_request: Request, response: Response): Promise<void> {
  const result = await getPlatformSettings();
  response.status(200).json(result);
}

export async function savePlatformSettingsHandler(request: Request, response: Response): Promise<void> {
  const result = await savePlatformSettings(request.body as Record<string, unknown>);
  response.status(200).json(result);
}

export async function listCommissionsHandler(_request: Request, response: Response): Promise<void> {
  const result = await listCommissions();
  response.status(200).json(result);
}

export async function saveCommissionHandler(request: Request, response: Response): Promise<void> {
  const commissionId = Array.isArray(request.params.commissionId)
    ? request.params.commissionId[0] ?? null
    : request.params.commissionId ?? null;

  const result = await saveCommission(
    commissionId,
    request.body as Record<string, unknown>
  );
  response.status(200).json(result);
}

export async function deleteCommissionHandler(request: Request, response: Response): Promise<void> {
  const commissionId = Array.isArray(request.params.commissionId)
    ? request.params.commissionId[0]
    : request.params.commissionId;

  if (!commissionId) {
    response.status(400).json({ error: "commissionId is required" });
    return;
  }

  await deleteCommission(commissionId);
  response.status(200).json({ success: true });
}
