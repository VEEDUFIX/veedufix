import type { Response } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.js";
import { logger } from "../../lib/logger.js";
import {
  AdminAiError,
  adminAiStatus,
  assistSupportTicket,
  auditCatalog,
  generateCatalogDraft,
  getBusinessInsights,
  getCatalogOptions,
  searchCatalogInNaturalLanguage
} from "./admin-ai.service.js";

async function respondWithAiError(
  request: AuthenticatedRequest,
  response: Response,
  action: string,
  operation: () => Promise<unknown>
): Promise<void> {
  try {
    response.status(200).json(await operation());
  } catch (error) {
    if (error instanceof AdminAiError) {
      response.status(error.status).json({ code: error.code, message: error.message });
      return;
    }
    logger.error({ adminId: request.auth?.userId, action, errorName: error instanceof Error ? error.name : "UnknownError" }, "Admin AI request failed");
    response.status(500).json({ code: "ADMIN_AI_REQUEST_FAILED", message: "The request could not be completed. Retry or use the existing Admin workflow." });
  }
}

export function adminAiStatusHandler(_request: AuthenticatedRequest, response: Response): void {
  response.status(200).json(adminAiStatus());
}

export function adminAiCatalogOptionsHandler(_request: AuthenticatedRequest, response: Response): Promise<void> {
  return respondWithAiError(_request, response, "catalog_options", getCatalogOptions);
}

export function adminAiCatalogDraftHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  const input = request.body as { serviceName: string; categoryId?: string; subcategoryId?: string; context?: string };
  return respondWithAiError(request, response, "catalog_draft", () => generateCatalogDraft(request.auth!.userId, input));
}

export function adminAiCatalogQualityHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  return respondWithAiError(request, response, "catalog_quality", () => auditCatalog(request.auth!.userId));
}

export function adminAiSearchHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  const input = request.body as { prompt: string };
  return respondWithAiError(request, response, "natural_search", () => searchCatalogInNaturalLanguage(input.prompt));
}

export function adminAiInsightsHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  const input = request.body as { days: number };
  return respondWithAiError(request, response, "business_insights", () => getBusinessInsights(request.auth!.userId, input.days));
}

export function adminAiSupportHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  const input = request.body as { ticketId: string; task: "summarize" | "categorize" | "draft_response"; additionalInstruction?: string };
  return respondWithAiError(request, response, "support_assistant", () => assistSupportTicket(request.auth!.userId, input));
}
