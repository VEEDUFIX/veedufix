import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import { logger } from "../../lib/logger.js";
import { aiService } from "./ai.service.js";

export async function chatHandler(request: AuthenticatedRequest, response: Response): Promise<void> {
  try {
    const { message, history } = request.body;
    const reply = await aiService.chat(message, history);
    response.status(200).json({ reply });
  } catch (error) {
    logger.error({ errorName: error instanceof Error ? error.name : "UnknownError" }, "AI chat request failed");
    response.status(500).json({ error: "Failed to process chat" });
  }
}
