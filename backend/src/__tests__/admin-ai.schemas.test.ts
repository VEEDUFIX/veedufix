import { describe, expect, it } from "vitest";
import {
  adminAiCatalogDraftSchema,
  adminAiDraftRequestSchema,
  adminAiInsightsRequestSchema,
  adminAiSearchRequestSchema,
  adminAiSupportDraftSchema,
  adminAiSupportRequestSchema
} from "../modules/admin-ai/admin-ai.schemas.js";

describe("Admin AI request and response schemas", () => {
  it("bounds catalog draft prompts and rejects unknown request fields", () => {
    expect(adminAiDraftRequestSchema.safeParse({ body: { serviceName: "AC repair", extra: "execute sql" } }).success).toBe(false);
    expect(adminAiDraftRequestSchema.safeParse({ body: { serviceName: "x" } }).success).toBe(false);
    expect(adminAiDraftRequestSchema.safeParse({ body: { serviceName: "AC repair", context: "x".repeat(1201) } }).success).toBe(false);
  });

  it("limits reporting periods and natural language query size", () => {
    expect(adminAiInsightsRequestSchema.safeParse({ body: { days: 91 } }).success).toBe(false);
    expect(adminAiSearchRequestSchema.safeParse({ body: { prompt: "  " } }).success).toBe(false);
    expect(adminAiSearchRequestSchema.safeParse({ body: { prompt: "x".repeat(301) } }).success).toBe(false);
  });

  it("requires an actual bounded support ticket task and bounded response fields", () => {
    expect(adminAiSupportRequestSchema.safeParse({ body: { ticketId: "ticket-1", task: "send_refund" } }).success).toBe(false);
    expect(adminAiSupportDraftSchema.safeParse({
      summary: "Customer reports a delayed booking.",
      category: "BOOKING",
      suggestedResponse: "We will investigate.",
      nextSteps: [],
      reviewCautions: [],
      refundAmount: 500
    }).success).toBe(false);
  });

  it("rejects generated catalog fields outside the descriptive allowlist", () => {
    const valid = {
      serviceName: "AC repair", shortDescription: "Repair help", description: "Inspect and repair the reported AC issue.",
      inclusions: [], exclusions: [], requiredSkills: [], requiredTools: [], requiredDocuments: [], requirements: [],
      searchAliases: [], seoTitle: "AC repair", seoDescription: "AC repair service", seoKeywords: "AC repair",
      suggestedEstimatedDurationMins: 60, durationRationale: "Review this estimate.",
      suggestedCategorySlug: null, suggestedSubcategorySlug: null, suggestedVariants: [], suggestedAddons: [], reviewNotes: []
    };
    expect(adminAiCatalogDraftSchema.safeParse(valid).success).toBe(true);
    expect(adminAiCatalogDraftSchema.safeParse({ ...valid, startingPrice: 500 }).success).toBe(false);
    expect(adminAiCatalogDraftSchema.safeParse({ ...valid, suggestedEstimatedDurationMins: 0 }).success).toBe(false);
  });
});
