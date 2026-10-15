import { describe, expect, it } from "vitest";
import { updateServiceSchema } from "../modules/catalog/catalog.schemas.js";

describe("updateServiceSchema feature configuration", () => {
  const parse = (body: Record<string, unknown>) =>
    updateServiceSchema.safeParse({ params: { id: "service-1" }, body });

  it("defers omitted maintenance and guarantee fields for merged-state validation", () => {
    expect(parse({ maintenanceEnabled: true }).success).toBe(true);
    expect(parse({ guaranteeEnabled: true }).success).toBe(true);
  });

  it("rejects explicitly empty maintenance intervals when enabling maintenance", () => {
    const result = parse({ maintenanceEnabled: true, maintenanceIntervalsMonths: [] });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues).toContainEqual(expect.objectContaining({
        path: ["body", "maintenanceIntervalsMonths"]
      }));
    }
  });

  it("rejects explicitly invalid guarantee fields when enabling the guarantee", () => {
    const result = parse({
      guaranteeEnabled: true,
      guaranteeClaimWindowDays: 0,
      guaranteeIssueCategories: [],
      guaranteeResolutionTypes: []
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues.map((issue) => issue.path.at(-1))).toEqual(expect.arrayContaining([
        "guaranteeClaimWindowDays",
        "guaranteeIssueCategories",
        "guaranteeResolutionTypes"
      ]));
    }
  });
});
