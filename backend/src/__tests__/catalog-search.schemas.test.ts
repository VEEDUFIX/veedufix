import { describe, expect, it } from "vitest";
import {
  autocompleteCatalogQuerySchema,
  catalogSearchQuerySchema
} from "../modules/catalog/catalog.schemas.js";

describe("catalog search query validation", () => {
  it("rejects empty and overlong search terms", () => {
    expect(catalogSearchQuerySchema.safeParse({ query: { q: "   " } }).success).toBe(false);
    expect(catalogSearchQuerySchema.safeParse({ query: { q: "x".repeat(121) } }).success).toBe(false);
    expect(autocompleteCatalogQuerySchema.safeParse({ query: { q: "x".repeat(121) } }).success).toBe(false);
  });

  it("keeps result limits bounded and paginated", () => {
    const parsed = catalogSearchQuerySchema.parse({
      query: { q: "plumbing", page: "2", pageSize: "30" }
    });
    expect(parsed.query).toMatchObject({ q: "plumbing", page: 2, pageSize: 30 });

    expect(
      catalogSearchQuerySchema.safeParse({ query: { q: "plumbing", pageSize: "101" } }).success
    ).toBe(false);
    expect(
      autocompleteCatalogQuerySchema.safeParse({ query: { q: "plumbing", limit: "51" } }).success
    ).toBe(false);
  });
});
