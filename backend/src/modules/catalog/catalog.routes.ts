import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  addServiceImagesSchema,
  addServicePricingSchema,
  catalogListQuerySchema,
  catalogSearchQuerySchema,
  catalogSlugParamsSchema,
  createCategorySchema,
  createServiceSchema,
  createSubcategorySchema,
  importCatalogSchema,
  reorderCategoriesSchema,
  updateCategorySchema,
  updatePriceRuleSchema,
  updateServiceSchema,
  updateSubcategorySchema
} from "./catalog.schemas.js";
import {
  addServiceImagesHandler,
  addServicePricingHandler,
  autocompleteCatalogHandler,
  createCategoryHandler,
  createServiceHandler,
  createSubcategoryHandler,
  deleteCategoryHandler,
  deleteServiceHandler,
  deleteSubcategoryHandler,
  exportCatalogHandler,
  homeCatalogHandler,
  importCatalogHandler,
  listCategoriesHandler,
  getCategoryHandler,
  getServiceHandler,
  getSubcategoryHandler,
  popularCatalogHandler,
  recommendedCatalogHandler,
  reorderCategoriesHandler,
  recentlyBookedCatalogHandler,
  searchCatalogHandler,
  trendingCatalogHandler,
  updateCategoryHandler,
  updatePriceRuleHandler,
  updateServiceHandler,
  updateSubcategoryHandler
} from "./catalog.controller.js";

export const catalogRouter = Router();
export const adminCatalogRouter = Router();

catalogRouter.get("/", validate(catalogListQuerySchema), listCategoriesHandler);
catalogRouter.get("/home", homeCatalogHandler);
catalogRouter.get("/search", validate(catalogSearchQuerySchema), searchCatalogHandler);
catalogRouter.get("/autocomplete", validate(catalogSearchQuerySchema), autocompleteCatalogHandler);
catalogRouter.get("/trending", trendingCatalogHandler);
catalogRouter.get("/popular", popularCatalogHandler);
catalogRouter.get("/recommended", recommendedCatalogHandler);
catalogRouter.get("/recently-booked", recentlyBookedCatalogHandler);
catalogRouter.get("/categories/:slug", validate(catalogSlugParamsSchema), getCategoryHandler);
catalogRouter.get("/subcategories/:slug", validate(catalogSlugParamsSchema), getSubcategoryHandler);
catalogRouter.get("/services/:slug", validate(catalogSlugParamsSchema), getServiceHandler);

adminCatalogRouter.use(requireAuth, requireRole("ADMIN"));
adminCatalogRouter.post("/categories", validate(createCategorySchema), createCategoryHandler);
adminCatalogRouter.patch("/categories/:id", validate(updateCategorySchema), updateCategoryHandler);
adminCatalogRouter.delete("/categories/:id", validate(updateCategorySchema), deleteCategoryHandler);
adminCatalogRouter.post("/categories/reorder", validate(reorderCategoriesSchema), reorderCategoriesHandler);
adminCatalogRouter.post("/subcategories", validate(createSubcategorySchema), createSubcategoryHandler);
adminCatalogRouter.patch("/subcategories/:id", validate(updateSubcategorySchema), updateSubcategoryHandler);
adminCatalogRouter.delete("/subcategories/:id", validate(updateSubcategorySchema), deleteSubcategoryHandler);
adminCatalogRouter.post("/services", validate(createServiceSchema), createServiceHandler);
adminCatalogRouter.patch("/services/:id", validate(updateServiceSchema), updateServiceHandler);
adminCatalogRouter.delete("/services/:id", validate(updateServiceSchema), deleteServiceHandler);
adminCatalogRouter.post("/services/:id/images", validate(addServiceImagesSchema), addServiceImagesHandler);
adminCatalogRouter.post("/services/:id/pricing-rules", validate(addServicePricingSchema), addServicePricingHandler);
adminCatalogRouter.patch("/pricing-rules/:id", validate(updatePriceRuleSchema), updatePriceRuleHandler);
adminCatalogRouter.post("/import", validate(importCatalogSchema), importCatalogHandler);
adminCatalogRouter.get("/export", exportCatalogHandler);
