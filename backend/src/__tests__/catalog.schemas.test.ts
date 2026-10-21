import { describe, expect, it } from "vitest";
import {
  createCategorySchema,
  addServicePricingSchema,
  createServiceSchema,
  createSubcategorySchema,
  importCatalogSchema,
  updateServiceSchema,
} from "../modules/catalog/catalog.schemas.js";

describe("catalog create schemas", () => {
  it("accepts explicit nulls for optional nullable category and subcategory fields", () => {
    expect(createCategorySchema.safeParse({
      body: { name: "Home repair", description: null, iconUrl: null, seoTitle: null, seoDescription: null },
    }).success).toBe(true);
    expect(createSubcategorySchema.safeParse({
      body: {
        categoryId: "category-1",
        name: "Plumbing",
        description: null,
        iconUrl: null,
        seoTitle: null,
        seoDescription: null,
      },
    }).success).toBe(true);
  });

  it("accepts the Admin service form's explicitly cleared optional fields", () => {
    const result = createServiceSchema.safeParse({
      body: {
        categoryId: "category-1",
        subcategoryId: "subcategory-1",
        name: "Tap repair",
        startingPrice: 500,
        estimatedDurationMins: 60,
        description: null,
        shortDescription: null,
        sacCode: null,
        cancellationPolicy: null,
        seoTitle: null,
        seoDescription: null,
        seoKeywords: null,
        iconUrl: null,
      },
    });
    expect(result.success).toBe(true);
  });

  it("requires a selected city only for city-scoped pricing rules", () => {
    const route = { params: { id: "service-1" } };
    const cityRule = {
      type: "CITY",
      title: "City price",
      price: 550,
    };
    expect(addServicePricingSchema.safeParse({ ...route, body: cityRule }).success)
      .toBe(false);
    expect(addServicePricingSchema.safeParse({
      ...route,
      body: { ...cityRule, cityId: "city-1" },
    }).success).toBe(true);
    expect(addServicePricingSchema.safeParse({
      ...route,
      body: { type: "BASE", title: "Base price", price: 500 },
    }).success).toBe(true);
  });
});

describe("catalog export import compatibility", () => {
  it("normalizes the admin export tree into validated import records", () => {
    const result = importCatalogSchema.safeParse({
      body: {
        categories: [{
          id: "category-export-id",
          name: "Home repair",
          slug: "home-repair",
          availabilityMode: "CUSTOM",
          serviceAreaAssignments: [{ serviceAreaId: "area-1" }],
          subcategories: [{
            id: "subcategory-export-id",
            name: "Plumbing",
            slug: "plumbing",
            basePrice: "250.00",
            catalogServices: [{
              id: "service-export-id",
              categoryId: "category-export-id",
              subcategoryId: "subcategory-export-id",
              name: "Tap repair",
              slug: "tap-repair",
              code: "TAP-REPAIR",
              startingPrice: "450.00",
              gstRate: "18.00",
              estimatedDurationMins: 60,
              requiredSkills: [{
                id: "requirement-1",
                isMandatory: true,
                sortOrder: 0,
                skill: { id: "skill-1", name: "Plumbing", slug: "plumbing" },
              }],
              pricingRules: [{
                id: "rule-1",
                cityId: null,
                type: "BASE",
                title: "Base",
                currency: "INR",
                price: "450.00",
                priority: 1,
                isActive: true,
              }],
            }],
          }],
        }],
      },
    });

    expect(result.success).toBe(true);
    if (result.success) {
      const category = result.data.body.categories[0];
      expect(category.serviceAreaIds).toEqual(["area-1"]);
      expect(category.subcategories[0].services?.[0]).toMatchObject({
        startingPrice: 450,
        gstRate: 18,
        requiredSkills: [{ name: "Plumbing", slug: "plumbing", isMandatory: true }],
        priceRules: [{ type: "BASE", price: 450 }],
      });
    }
  });

  it("rejects exported services with invalid feature-policy configuration", () => {
    const result = importCatalogSchema.safeParse({
      body: {
        categories: [{
          name: "Home repair",
          slug: "home-repair",
          subcategories: [{
            name: "Plumbing",
            slug: "plumbing",
            services: [{
              name: "Tap repair",
              slug: "tap-repair",
              startingPrice: 450,
              estimatedDurationMins: 60,
              maintenanceEnabled: true,
              maintenanceIntervalsMonths: [],
            }],
          }],
        }],
      },
    });
    expect(result.success).toBe(false);
  });
});

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
