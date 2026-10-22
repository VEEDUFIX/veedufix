import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { fakeEnv } = vi.hoisted(() => ({
  fakeEnv: { GEMINI_API_KEY: "server-only-test-key", GEMINI_FREE_TIER_CONFIRMED: false }
}));

vi.mock("../config/env.js", () => ({ env: fakeEnv }));

import { AiProviderError, GEMINI_FREE_MODEL, GeminiBackendAiProvider } from "../lib/ai-provider.js";

describe("Gemini backend provider", () => {
  const originalFetch = globalThis.fetch;
  let provider: GeminiBackendAiProvider;

  beforeEach(() => {
    provider = new GeminiBackendAiProvider();
    fakeEnv.GEMINI_API_KEY = "server-only-test-key";
    fakeEnv.GEMINI_FREE_TIER_CONFIRMED = false;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    vi.restoreAllMocks();
  });

  it("refuses to call Gemini unless the free-tier project is explicitly confirmed", async () => {
    const fetchMock = vi.fn();
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    await expect(provider.generateText("system", { prompt: "hello" })).rejects.toMatchObject<Partial<AiProviderError>>({
      code: "AI_CONFIGURATION_REQUIRED",
      status: 503
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("uses the fixed free model, server-only key header, and structured response schema", async () => {
    fakeEnv.GEMINI_FREE_TIER_CONFIRMED = true;
    const responseSchema = { type: "object", required: ["draft"], properties: { draft: { type: "string" } } };
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      expect(init?.headers).toEqual({ "content-type": "application/json", "x-goog-api-key": "server-only-test-key" });
      const sent = JSON.parse(String(init?.body)) as { generationConfig: Record<string, unknown> };
      expect(sent.generationConfig.responseFormat).toEqual({ text: { mimeType: "APPLICATION_JSON", schema: responseSchema } });
      return new Response(JSON.stringify({
        candidates: [{ content: { parts: [{ text: '{"draft":"editable"}' }] }, finishReason: "STOP" }],
        usageMetadata: { promptTokenCount: 20, candidatesTokenCount: 8 }
      }), { status: 200, headers: { "content-type": "application/json" } });
    });
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    const result = await provider.generateJson("system", { prompt: "hello" }, responseSchema, (value) => {
      const object = value as { draft?: unknown };
      if (typeof object.draft !== "string") throw new Error("invalid draft");
      return object;
    });

    expect(GEMINI_FREE_MODEL).toBe("gemini-3.5-flash-lite");
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(String(fetchMock.mock.calls[0]?.[0])).toContain(`/models/${GEMINI_FREE_MODEL}:generateContent`);
    expect(result).toEqual({ value: { draft: "editable" }, usage: { promptTokens: 20, outputTokens: 8 } });
    expect(JSON.stringify(result)).not.toContain("server-only-test-key");
  });

  it("maps quota exhaustion to a retryable 429 without retrying or selecting a paid fallback", async () => {
    fakeEnv.GEMINI_FREE_TIER_CONFIRMED = true;
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ error: { status: "RESOURCE_EXHAUSTED" } }), { status: 429 }));
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    await expect(provider.generateText("system", { prompt: "hello" })).rejects.toMatchObject<Partial<AiProviderError>>({
      code: "AI_QUOTA_EXHAUSTED",
      status: 429
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("rejects syntactically valid output that fails backend validation", async () => {
    fakeEnv.GEMINI_FREE_TIER_CONFIRMED = true;
    globalThis.fetch = vi.fn(async () => new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: '{"draft":3}' }] }, finishReason: "STOP" }]
    }), { status: 200 })) as unknown as typeof fetch;

    await expect(provider.generateJson("system", {}, { type: "object" }, () => {
      throw new Error("schema rejected");
    })).rejects.toMatchObject<Partial<AiProviderError>>({ code: "AI_INVALID_RESPONSE", status: 502 });
  });
});
