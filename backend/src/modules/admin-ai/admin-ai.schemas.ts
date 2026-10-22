import { z } from "zod";

const stringArray = { type: "array", items: { type: "string" } } as const;

export const adminAiCatalogDraftResponseSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "serviceName", "shortDescription", "description", "inclusions", "exclusions", "requiredSkills",
    "requiredTools", "requiredDocuments", "requirements", "searchAliases", "seoTitle", "seoDescription",
    "seoKeywords", "suggestedEstimatedDurationMins", "durationRationale", "suggestedCategorySlug",
    "suggestedSubcategorySlug", "suggestedVariants", "suggestedAddons", "reviewNotes"
  ],
  properties: {
    serviceName: { type: "string" }, shortDescription: { type: "string" }, description: { type: "string" },
    inclusions: stringArray, exclusions: stringArray, requiredSkills: stringArray, requiredTools: stringArray,
    requiredDocuments: stringArray, requirements: stringArray, searchAliases: stringArray,
    seoTitle: { type: "string" }, seoDescription: { type: "string" }, seoKeywords: { type: "string" },
    suggestedEstimatedDurationMins: { type: ["integer", "null"] }, durationRationale: { type: "string" },
    suggestedCategorySlug: { type: ["string", "null"] }, suggestedSubcategorySlug: { type: ["string", "null"] },
    suggestedVariants: { type: "array", items: { type: "object", additionalProperties: false, required: ["name", "description"], properties: { name: { type: "string" }, description: { type: "string" } } } },
    suggestedAddons: { type: "array", items: { type: "object", additionalProperties: false, required: ["name", "description"], properties: { name: { type: "string" }, description: { type: "string" } } } },
    reviewNotes: stringArray
  }
} as const;

export const adminAiSemanticFindingsResponseSchema = {
  type: "object", additionalProperties: false, required: ["findings"], properties: {
    findings: { type: "array", items: { type: "object", additionalProperties: false, required: ["serviceId", "problem", "whyItMatters", "suggestedFix", "confidence"], properties: {
      serviceId: { type: "string" }, problem: { type: "string" }, whyItMatters: { type: "string" }, suggestedFix: { type: "string" }, confidence: { type: "number", minimum: 0, maximum: 1 }
    } } }
  }
} as const;

export const adminAiSupportDraftResponseSchema = {
  type: "object", additionalProperties: false,
  required: ["summary", "category", "suggestedResponse", "nextSteps", "reviewCautions"],
  properties: {
    summary: { type: "string" }, category: { type: "string", enum: ["BOOKING", "PAYMENT", "PARTNER", "SERVICE_QUALITY", "APP_TECHNICAL", "ACCOUNT", "OTHER"] },
    suggestedResponse: { type: "string" }, nextSteps: stringArray, reviewCautions: stringArray
  }
} as const;

export const adminAiBusinessNarrativeResponseSchema = {
  type: "object", additionalProperties: false,
  required: ["summary", "observations", "recommendations", "limitations"],
  properties: { summary: { type: "string" }, observations: stringArray, recommendations: stringArray, limitations: stringArray }
} as const;

const id = z.string().trim().min(1).max(120);

export const adminAiDraftRequestSchema = z.object({
  body: z.object({
    serviceName: z.string().trim().min(2).max(160),
    categoryId: id.optional(),
    subcategoryId: id.optional(),
    context: z.string().trim().max(1200).optional()
  }).strict()
});

export const adminAiSearchRequestSchema = z.object({
  body: z.object({ prompt: z.string().trim().min(3).max(300) }).strict()
});

export const adminAiInsightsRequestSchema = z.object({
  body: z.object({ days: z.coerce.number().int().min(7).max(90).default(30) }).strict()
});

export const adminAiSupportRequestSchema = z.object({
  body: z.object({
    ticketId: id,
    task: z.enum(["summarize", "categorize", "draft_response"]),
    additionalInstruction: z.string().trim().max(500).optional()
  }).strict()
});

export const adminAiCatalogDraftSchema = z.object({
  serviceName: z.string().trim().min(2).max(160),
  shortDescription: z.string().trim().max(500),
  description: z.string().trim().max(5000),
  inclusions: z.array(z.string().trim().min(1).max(300)).max(30),
  exclusions: z.array(z.string().trim().min(1).max(300)).max(30),
  requiredSkills: z.array(z.string().trim().min(1).max(120)).max(20),
  requiredTools: z.array(z.string().trim().min(1).max(120)).max(20),
  requiredDocuments: z.array(z.string().trim().min(1).max(120)).max(20),
  requirements: z.array(z.string().trim().min(1).max(300)).max(30),
  searchAliases: z.array(z.string().trim().min(1).max(80)).max(30),
  seoTitle: z.string().trim().max(160),
  seoDescription: z.string().trim().max(300),
  seoKeywords: z.string().trim().max(500),
  suggestedEstimatedDurationMins: z.number().int().min(1).max(1440).nullable(),
  durationRationale: z.string().trim().max(300),
  suggestedCategorySlug: z.string().trim().max(120).nullable(),
  suggestedSubcategorySlug: z.string().trim().max(120).nullable(),
  suggestedVariants: z.array(z.object({
    name: z.string().trim().min(2).max(120),
    description: z.string().trim().max(500)
  }).strict()).max(10),
  suggestedAddons: z.array(z.object({
    name: z.string().trim().min(2).max(120),
    description: z.string().trim().max(500)
  }).strict()).max(10),
  reviewNotes: z.array(z.string().trim().min(1).max(300)).max(12)
}).strict();

export const adminAiSemanticFindingSchema = z.object({
  serviceId: id,
  problem: z.string().trim().min(1).max(300),
  whyItMatters: z.string().trim().min(1).max(500),
  suggestedFix: z.string().trim().min(1).max(500),
  confidence: z.number().min(0).max(1)
}).strict();

export const adminAiSemanticFindingsSchema = z.object({
  findings: z.array(adminAiSemanticFindingSchema).max(60)
}).strict();

export const adminAiSupportDraftSchema = z.object({
  summary: z.string().trim().min(1).max(1200),
  category: z.enum(["BOOKING", "PAYMENT", "PARTNER", "SERVICE_QUALITY", "APP_TECHNICAL", "ACCOUNT", "OTHER"]),
  suggestedResponse: z.string().trim().max(2000),
  nextSteps: z.array(z.string().trim().min(1).max(300)).max(8),
  reviewCautions: z.array(z.string().trim().min(1).max(300)).max(8)
}).strict();

export const adminAiBusinessNarrativeSchema = z.object({
  summary: z.string().trim().min(1).max(800),
  observations: z.array(z.string().trim().min(1).max(300)).max(8),
  recommendations: z.array(z.string().trim().min(1).max(300)).max(6),
  limitations: z.array(z.string().trim().min(1).max(300)).max(6)
}).strict();

export type AdminAiCatalogDraft = z.infer<typeof adminAiCatalogDraftSchema>;
export type AdminAiSupportDraft = z.infer<typeof adminAiSupportDraftSchema>;
