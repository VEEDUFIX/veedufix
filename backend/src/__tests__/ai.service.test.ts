import { beforeEach, describe, expect, it, vi } from "vitest";

const { generateText } = vi.hoisted(() => ({ generateText: vi.fn() }));

vi.mock("../lib/ai-provider.js", () => ({
  AiProviderError: class AiProviderError extends Error {
    constructor(readonly status: number, readonly code: string, message: string) { super(message); }
  },
  backendAiProvider: { generateText }
}));

import { AiService } from "../modules/ai/ai.service.js";

describe("customer AI service privacy controls", () => {
  beforeEach(() => vi.clearAllMocks());

  it("sends only bounded, redacted customer text and recent history to the provider", async () => {
    generateText.mockResolvedValue("You can book an AC repair in the app.");
    const service = new AiService();
    const history = Array.from({ length: 8 }, (_, index) => ({
      role: index % 2 === 0 ? "user" as const : "model" as const,
      parts: [{ text: `Old message ${index} phone 9876543210` }]
    }));

    const reply = await service.chat("Email person@example.com or call 9876543210", history);

    expect(reply).toContain("book an AC repair");
    expect(generateText).toHaveBeenCalledTimes(1);
    const [, input] = generateText.mock.calls[0] as [string, { message: string; history: Array<{ text: string }> }];
    expect(input.message).not.toContain("person@example.com");
    expect(input.message).not.toContain("9876543210");
    expect(input.history).toHaveLength(6);
    expect(JSON.stringify(input)).not.toContain("9876543210");
  });
});
