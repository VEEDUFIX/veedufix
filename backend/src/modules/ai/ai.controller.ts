import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import { logger } from "../../lib/logger.js";
import { AiProviderError } from "../../lib/ai-provider.js";
import { AiConfigurationError, aiService } from "./ai.service.js";

export async function chatHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  try {
    const { message, history } = request.body;
    const reply = await aiService.chat(message, history);
    response.status(200).json({ reply });
  } catch (error) {
    if (error instanceof AiConfigurationError) {
      response.status(503).json({ code: "AI_CONFIGURATION_REQUIRED", message: error.message });
      return;
    }
    if (error instanceof AiProviderError) {
      response.status(error.status).json({ code: error.code, message: error.message });
      return;
    }
    logger.error({ errorName: error instanceof Error ? error.name : "UnknownError" }, "AI chat request failed");
    response.status(502).json({ error: "AI provider unavailable. Please try again." });
  }
}
