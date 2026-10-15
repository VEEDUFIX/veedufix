import { describe, expect, it } from "vitest";
import {
  expandSearchQuery,
  normalizeSearchText,
  searchRelevanceScore
} from "../modules/catalog/search-vocabulary.js";

describe("catalog search vocabulary", () => {
  it("normalizes case, punctuation, and repeated whitespace", () => {
    expect(normalizeSearchText("  AC---Not   Cooling ")).toBe("ac not cooling");
    expect(normalizeSearchText("A/C service")).toBe("ac service");
  });

  it("preserves combining marks used by accented and Indic text", () => {
    expect(normalizeSearchText("café")).toBe("café");
    expect(normalizeSearchText("தமிழ் சேவை")).toBe("தமிழ் சேவை");
  });

  it("expands customer language into the existing service vocabulary", () => {
    expect(expandSearchQuery("AC not cooling")).toEqual(
      expect.arrayContaining(["air conditioning repair", "ac repair"])
    );
    expect(expandSearchQuery("leak repair")).toContain("leak repair");
    expect(expandSearchQuery("electrician")).toContain("electrical repair");
  });

  it("corrects a one-character typo for known common services", () => {
    expect(expandSearchQuery("plumbng")).toContain("plumbing");
  });

  it("ranks direct name matches above loosely related results", () => {
    expect(searchRelevanceScore("AC Repair", "AC repair")).toBeGreaterThan(
      searchRelevanceScore("Home Cleaning", "AC repair")
    );
    expect(searchRelevanceScore("Vacuum repair", "ac")).toBe(0);
  });
});
