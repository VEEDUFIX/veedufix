import { Router } from "express";
import { prisma } from "../../lib/prisma.js";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  addServiceImagesSchema,
  addServicePricingSchema,
  autocompleteCatalogQuerySchema,
  catalogListQuerySchema,
  catalogSearchQuerySchema,
  catalogSlugParamsSchema,
  createCategorySchema,
  createServiceSchema,
  createSubcategorySchema,
  importCatalogSchema,
  reorderCategoriesSchema,
  reorderServicesSchema,
  reorderSubcategoriesSchema,
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
  reorderServicesHandler,
  reorderSubcategoriesHandler,
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
catalogRouter.get("/categories", validate(catalogListQuerySchema), listCategoriesHandler);
catalogRouter.get("/home", homeCatalogHandler);
catalogRouter.get("/services", validate(catalogSearchQuerySchema), searchCatalogHandler);

// GET /api/catalog/coupons — Returns active public coupons
catalogRouter.get('/coupons', async (_request, response) => {
  const now = new Date();
  const coupons = await prisma.coupon.findMany({
    where: {
      isActive: true,
      OR: [
        { endsAt: null },
        { endsAt: { gt: now } },
      ],
    },
    select: {
      code: true,
      description: true,
      type: true,
      value: true,
      maxDiscount: true,
      minOrderAmount: true,
      endsAt: true,
    },
    orderBy: { createdAt: 'desc' },
    take: 20,
  });

  const mappedCoupons = coupons.map((c: any) => ({
    code: c.code,
    title: c.code,
    description: c.description,
    discountType: c.type,
    discountValue: c.value,
    maxDiscountAmount: c.maxDiscount,
    minOrderAmount: c.minOrderAmount,
    expiresAt: c.endsAt,
  }));

  response.status(200).json({ coupons: mappedCoupons });
});

catalogRouter.get("/search", validate(catalogSearchQuerySchema), searchCatalogHandler);
catalogRouter.get("/autocomplete", validate(autocompleteCatalogQuerySchema), autocompleteCatalogHandler);

catalogRouter.get("/professionals", async (_request, response) => {
  const professionals = await prisma.workerProfile.findMany({
    where: { 
      isAvailable: true, 
      verificationStatus: "VERIFIED" 
    },
    include: {
      user: { select: { name: true } }
    },
    orderBy: { averageRating: "desc" },
    take: 10
  });

  response.status(200).json({
    professionals: professionals.map((p: any) => ({
      name: p.displayName ?? p.user.name ?? "Professional",
      role: "Professional",
      experience: `${p.completedJobsCount} jobs`,
      rating: Number(p.averageRating),
      distance: "Nearby",
      price: "Book for quote",
      verified: p.verificationStatus === "VERIFIED",
      accent: 0xFF10B981
    }))
  });
});

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
adminCatalogRouter.post("/subcategories/reorder", validate(reorderSubcategoriesSchema), reorderSubcategoriesHandler);
adminCatalogRouter.post("/services", validate(createServiceSchema), createServiceHandler);
adminCatalogRouter.patch("/services/:id", validate(updateServiceSchema), updateServiceHandler);
adminCatalogRouter.delete("/services/:id", validate(updateServiceSchema), deleteServiceHandler);
adminCatalogRouter.post("/services/reorder", validate(reorderServicesSchema), reorderServicesHandler);
adminCatalogRouter.post("/services/:id/images", validate(addServiceImagesSchema), addServiceImagesHandler);
adminCatalogRouter.post("/services/:id/pricing-rules", validate(addServicePricingSchema), addServicePricingHandler);
adminCatalogRouter.patch("/pricing-rules/:id", validate(updatePriceRuleSchema), updatePriceRuleHandler);
adminCatalogRouter.post("/import", validate(importCatalogSchema), importCatalogHandler);
adminCatalogRouter.get("/export", exportCatalogHandler);
