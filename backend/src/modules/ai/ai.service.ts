import { logger } from "../../lib/logger.js";
import { AiProviderError, backendAiProvider } from "../../lib/ai-provider.js";
import type { ChatMessage } from "./ai.schemas.js";

export class AiConfigurationError extends Error {
  constructor() {
    super("AI chat is disabled until a backend Gemini key and free-tier-only project are configured.");
    this.name = "AiConfigurationError";
  }
}

export class AiService {
  async chat(message: string, chatHistory: ChatMessage[] = []): Promise<string> {
    try {
      const systemPrompt = `You are Veedufix AI, a helpful, friendly, and concise assistant for a home services marketplace app.
Your job is to help customers find services (like AC repair, Plumbing, Cleaning, Electrician) and answer general questions about the app.
Keep responses under 3 sentences. Be polite. Suggest booking a professional on the app. Do not request or repeat personal contact details.`;
      const sanitizedHistory = chatHistory.slice(-6).map((entry) => ({
        role: entry.role,
        text: redactCustomerText(entry.parts[0]?.text ?? "", 500)
      }));
      return await backendAiProvider.generateText(systemPrompt, {
        message: redactCustomerText(message, 1000),
        history: sanitizedHistory
      });
    } catch (error) {
      if (error instanceof AiProviderError && error.code === "AI_CONFIGURATION_REQUIRED") {
        throw new AiConfigurationError();
      }
      if (error instanceof AiProviderError) throw error;
      logger.error({ errorName: error instanceof Error ? error.name : "UnknownError" }, "AI provider request failed");
      throw new Error("AI provider request failed");
    }
  }
}

function redactCustomerText(value: string, maximumLength: number): string {
  return value
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[redacted email]")
    .replace(/\b(?:\+?\d[\d\s().-]{7,}\d)\b/g, (candidate) =>
      candidate.replace(/\D/g, "").length >= 10 ? "[redacted phone or number]" : candidate
    )
    .slice(0, maximumLength);
}

export const aiService = new AiService();
