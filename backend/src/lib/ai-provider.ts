import { env } from "../config/env.js";

export const GEMINI_FREE_MODEL = "gemini-3.5-flash-lite";
const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_FREE_MODEL}:generateContent`;
const REQUEST_TIMEOUT_MS = 20_000;

export type ProviderUsage = { promptTokens?: number; outputTokens?: number };
export type ProviderResult<T> = { value: T; usage: ProviderUsage };

export interface BackendAiProvider {
  generateText(systemInstruction: string, input: unknown): Promise<string>;
  generateJson<T>(
    systemInstruction: string,
    input: unknown,
    responseSchema: Record<string, unknown>,
    parse: (value: unknown) => T
  ): Promise<ProviderResult<T>>;
}

export class AiProviderError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message);
    this.name = "AiProviderError";
  }
}

export function isGeminiConfigured(): boolean {
  return Boolean(env.GEMINI_API_KEY?.trim() && env.GEMINI_FREE_TIER_CONFIRMED);
}

function requireGeminiConfiguration(): string {
  if (!env.GEMINI_API_KEY?.trim() || !env.GEMINI_FREE_TIER_CONFIRMED) {
    throw new AiProviderError(
      503,
      "AI_CONFIGURATION_REQUIRED",
      "AI assistance is disabled. Configure a backend Gemini API key and confirm that its Google AI Studio project has billing disabled and uses the free tier."
    );
  }
  return env.GEMINI_API_KEY.trim();
}

function readErrorStatus(payload: unknown): string {
  if (!payload || typeof payload !== "object") return "";
  const error = (payload as { error?: unknown }).error;
  if (!error || typeof error !== "object") return "";
  const status = (error as { status?: unknown }).status;
  return typeof status === "string" ? status.toUpperCase() : "";
}

export class GeminiBackendAiProvider implements BackendAiProvider {
  async generateText(systemInstruction: string, input: unknown): Promise<string> {
    const response = await this.request(systemInstruction, input, undefined, 400, false);
    return response.text;
  }

  async generateJson<T>(
    systemInstruction: string,
    input: unknown,
    responseSchema: Record<string, unknown>,
    parse: (value: unknown) => T
  ): Promise<ProviderResult<T>> {
    const response = await this.request(systemInstruction, input, responseSchema, 1800, true);
    try {
      const value = parse(JSON.parse(response.text) as unknown);
      return { value, usage: response.usage };
    } catch {
      throw new AiProviderError(502, "AI_INVALID_RESPONSE", "The AI provider returned data that did not match the required response schema.");
    }
  }

  private async request(
    systemInstruction: string,
    input: unknown,
    responseSchema: Record<string, unknown> | undefined,
    maxOutputTokens: number,
    jsonMode: boolean
  ): Promise<{ text: string; usage: ProviderUsage }> {
    const apiKey = requireGeminiConfiguration();
    let response: Response;
    try {
      response = await fetch(GEMINI_ENDPOINT, {
        method: "POST",
        headers: { "content-type": "application/json", "x-goog-api-key": apiKey },
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemInstruction }] },
          contents: [{ role: "user", parts: [{ text: JSON.stringify(input) }] }],
          generationConfig: {
            ...(jsonMode ? { responseFormat: { text: { mimeType: "APPLICATION_JSON", schema: responseSchema } } } : {}),
            maxOutputTokens
          }
        })
      });
    } catch (error) {
      if (error instanceof Error && (error.name === "AbortError" || error.name === "TimeoutError")) {
        throw new AiProviderError(504, "AI_PROVIDER_TIMEOUT", "The AI provider took too long. Retry the request.");
      }
      throw new AiProviderError(502, "AI_PROVIDER_UNAVAILABLE", "The AI provider is unavailable. Retry the request.");
    }

    const payload: unknown = await response.json().catch(() => null);
    if (!response.ok) {
      const providerStatus = readErrorStatus(payload);
      if (response.status === 429 || providerStatus === "RESOURCE_EXHAUSTED") {
        throw new AiProviderError(429, "AI_QUOTA_EXHAUSTED", "Gemini's free-tier quota or rate limit has been reached. Try again after the quota resets or the rate limit clears.");
      }
      if (response.status === 401 || response.status === 403) {
        throw new AiProviderError(503, "AI_CONFIGURATION_INVALID", "Gemini rejected the server configuration. Check the backend key and its AI Studio project settings.");
      }
      throw new AiProviderError(502, "AI_PROVIDER_UNAVAILABLE", "The AI provider is unavailable. Retry the request or use the existing Admin workflow.");
    }

    const candidate = payload && typeof payload === "object"
      ? (payload as { candidates?: Array<{ content?: { parts?: Array<{ text?: unknown }> }; finishReason?: string }> }).candidates?.[0]
      : undefined;
    const text = candidate?.content?.parts?.map((part) => typeof part.text === "string" ? part.text : "").join("").trim();
    if (!text || candidate?.finishReason === "MAX_TOKENS") {
      throw new AiProviderError(502, "AI_INVALID_RESPONSE", "The AI provider returned an incomplete response. Retry the request.");
    }
    const usageMetadata = payload && typeof payload === "object"
      ? (payload as { usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number } }).usageMetadata
      : undefined;
    return {
      text,
      usage: { promptTokens: usageMetadata?.promptTokenCount, outputTokens: usageMetadata?.candidatesTokenCount }
    };
  }
}

export const backendAiProvider: BackendAiProvider = new GeminiBackendAiProvider();
