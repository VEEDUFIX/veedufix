import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AdminAiProvider } from "../modules/admin-ai/admin-ai.service.js";

const { prismaMock } = vi.hoisted(() => ({
  prismaMock: {
    serviceCategory: { findMany: vi.fn() },
    serviceSubcategory: { findMany: vi.fn() },
    service: { findMany: vi.fn() },
    booking: { findMany: vi.fn() },
    payment: { findMany: vi.fn() },
    workerProfile: { count: vi.fn() },
    supportTicket: { groupBy: vi.fn(), findUnique: vi.fn() }
  }
}));

vi.mock("../lib/prisma.js", () => ({ prisma: prismaMock }));
vi.mock("../lib/logger.js", () => ({ logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() } }));

import {
  AdminAiError,
  assistSupportTicket,
  auditCatalog,
  generateCatalogDraft,
  parseNaturalFilters,
  searchCatalogInNaturalLanguage,
  setAdminAiProviderForTesting
} from "../modules/admin-ai/admin-ai.service.js";

const catalogDraft = {
  serviceName: "AC inspection",
  shortDescription: "Inspection and diagnosis of air-conditioning issues.",
  description: "A technician inspects the air-conditioning unit and explains the likely cause of the reported issue.",
  inclusions: ["Visual inspection"],
  exclusions: [],
  requiredSkills: ["Air conditioning"],
  requiredTools: [],
  requiredDocuments: [],
  requirements: [],
  searchAliases: ["AC check"],
  seoTitle: "AC inspection",
  seoDescription: "Inspection of an air-conditioning unit.",
  seoKeywords: "AC, air conditioning",
  suggestedEstimatedDurationMins: 60,
  durationRationale: "A reviewable estimate based on the described inspection scope.",
  suggestedCategorySlug: "home-repair",
  suggestedSubcategorySlug: null,
  suggestedVariants: [],
  suggestedAddons: [],
  reviewNotes: ["Review the scope before publishing."]
};

const supportDraft = {
  summary: "The customer reports a booking issue.",
  category: "BOOKING" as const,
  suggestedResponse: "Please share the booking reference so we can check.",
  nextSteps: ["Review the booking record."],
  reviewCautions: ["This is a draft and has not been sent."]
};

function useProvider(output: unknown, observed?: (system: string, input: unknown) => void) {
  const provider: AdminAiProvider = {
    async generateJson<T>(system: string, input: unknown, parse: (value: unknown) => T) {
      observed?.(system, input);
      return { value: parse(output), usage: { promptTokens: 10, outputTokens: 12 } };
    }
  };
  return setAdminAiProviderForTesting(provider);
}

describe("Admin AI service safety and catalog behavior", () => {
  let restoreProvider: (() => void) | undefined;
  beforeEach(() => {
    vi.clearAllMocks();
    restoreProvider?.();
    restoreProvider = undefined;
  });

  it("validates selected catalog records and maps the model slug back to real IDs", async () => {
    prismaMock.serviceCategory.findMany.mockResolvedValue([
      { id: "category-1", name: "Home Repair", slug: "home-repair" }
    ]);
    prismaMock.serviceSubcategory.findMany.mockResolvedValue([]);
    let sentInput: unknown;
    restoreProvider = useProvider(catalogDraft, (_system, input) => { sentInput = input; });

    const result = await generateCatalogDraft("admin-1", {
      serviceName: "AC inspection",
      categoryId: "category-1"
    });

    expect(result).toMatchObject({ generated: true, verified: false, categoryId: "category-1", subcategoryId: null });
    expect((sentInput as { availableCategories: unknown[] }).availableCategories).toEqual([
      { name: "Home Repair", slug: "home-repair" }
    ]);
    expect(JSON.stringify(result)).not.toMatch(/price|tax|SAC/i);
  });

  it("rejects an unknown category without asking the provider to invent catalog data", async () => {
    prismaMock.serviceCategory.findMany.mockResolvedValue([]);
    prismaMock.serviceSubcategory.findMany.mockResolvedValue([]);
    const provider = { generateJson: vi.fn() } as unknown as AdminAiProvider;
    restoreProvider = setAdminAiProviderForTesting(provider);

    await expect(generateCatalogDraft("admin-1", { serviceName: "AC inspection", categoryId: "made-up" }))
      .rejects.toMatchObject<Partial<AdminAiError>>({ code: "UNKNOWN_CATEGORY", status: 400 });
    expect(provider.generateJson).not.toHaveBeenCalled();
  });

  it("maps natural search only to bounded read-only Prisma filters", async () => {
    const parsed = parseNaturalFilters("show inactive AC services without images");
    expect(parsed.needsClarification).toBe(false);
    expect(parsed.where).toMatchObject({ isActive: false, images: { none: {} } });
    expect(parsed.filters.searchTerms).toContain("ac");

    prismaMock.service.findMany.mockResolvedValue([]);
    const result = await searchCatalogInNaturalLanguage("show inactive AC services without images");
    expect(result).toMatchObject({ needsClarification: false, count: 0, services: [] });
    expect(prismaMock.service.findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 250 }));
  });

  it("asks for clarification rather than interpreting unsupported actions", async () => {
    const result = await searchCatalogInNaturalLanguage("delete every service");
    expect(result.needsClarification).toBe(true);
    expect(prismaMock.service.findMany).not.toHaveBeenCalled();
  });

  it("audits catalog records with no subcategory without throwing", async () => {
    prismaMock.service.findMany.mockResolvedValue([{
      id: "service-1", name: "AC inspection", description: "A", shortDescription: null,
      seoTitle: null, seoDescription: null, requirements: [], inclusions: [], exclusions: [],
      categoryId: "category-1", subcategoryId: null, isActive: true, publicationStatus: "DRAFT",
      category: { id: "category-1", name: "Home Repair" }, subcategory: null,
      images: [], searchKeywords: []
    }]);

    const result = await auditCatalog("admin-1");
    expect(result.recordsAnalyzed).toBe(1);
    expect(result.findings.map((finding) => finding.code)).toEqual(expect.arrayContaining([
      "DESCRIPTION_WEAK", "IMAGE_MISSING", "ALIASES_MISSING", "SHORT_DESCRIPTION_MISSING"
    ]));
  });

  it("redacts contact details, excludes internal replies, and marks support output as a draft", async () => {
    prismaMock.supportTicket.findUnique.mockResolvedValue({
      id: "ticket-1", subject: "Call 9876543210", message: "Email me at person@example.com",
      status: "OPEN", createdAt: new Date(),
      replies: [
        { message: "Internal note secret", isInternal: true, createdAt: new Date() },
        { message: "We are reviewing the booking.", isInternal: false, createdAt: new Date() }
      ]
    });
    let capturedSystem = "";
    let capturedInput = "";
    restoreProvider = useProvider(supportDraft, (system, input) => {
      capturedSystem = system;
      capturedInput = JSON.stringify(input);
    });

    const result = await assistSupportTicket("admin-1", { ticketId: "ticket-1", task: "summarize" });
    expect(result).toMatchObject({ sourceVerified: true, generated: true, draft: supportDraft });
    expect(capturedSystem).toContain("untrusted customer content");
    expect(capturedInput).not.toContain("9876543210");
    expect(capturedInput).not.toContain("person@example.com");
    expect(capturedInput).not.toContain("Internal note secret");
  });
});
