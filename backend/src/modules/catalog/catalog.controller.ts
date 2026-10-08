import { Request, Response } from "express";
import { prisma } from "../../lib/prisma.js";
import { catalogService } from "./catalog.service.js";
import { getServiceReviews } from "../reviews/reviews.service.js";

type AuthRequest = Request & {
  auth?: {
    userId: string;
    role: "CUSTOMER" | "WORKER" | "ADMIN";
  };
};

export async function listCategoriesHandler(request: Request, response: Response): Promise<void> {
  const { locale, cityId } = request.query as {
    locale?: string;
    cityId?: string;
  };

  const categories = await catalogService.resolveCatalogTree(cityId, locale);

  response.status(200).json({ categories });
}

export async function getCategoryHandler(request: Request, response: Response): Promise<void> {
  const category = await catalogService.resolveCategoryBySlug(String(request.params.slug));
  if (!category) {
    response.status(404).json({ message: "Category not found" });
    return;
  }

  response.status(200).json({ category });
}

export async function getSubcategoryHandler(request: Request, response: Response): Promise<void> {
  const subcategory = await catalogService.resolveSubcategoryBySlug(String(request.params.slug));
  if (!subcategory) {
    response.status(404).json({ message: "Subcategory not found" });
    return;
  }

  response.status(200).json({ subcategory });
}

export async function getServiceHandler(request: Request, response: Response): Promise<void> {
  const { cityId } = request.query as { cityId?: string };
  const service = await catalogService.resolveServiceBySlug(String(request.params.slug), cityId);
  if (!service) {
    response.status(404).json({ message: "Service not found" });
    return;
  }

  response.status(200).json({
    service,
    effectivePrice: service.pricingRules.length > 0 ? service.pricingRules[0].price : service.startingPrice
  });
}

export async function getServiceReviewsHandler(request: Request, response: Response): Promise<void> {
  const service = await catalogService.resolveServiceBySlug(String(request.params.slug));
  if (!service || !service.isActive) {
    response.status(404).json({ message: "Service not found" });
    return;
  }

  response.status(200).json({ reviews: await getServiceReviews(service.id) });
}

export async function searchCatalogHandler(request: Request, response: Response): Promise<void> {
  const { q, locale, cityId, categorySlug, subcategorySlug, page, pageSize } = request.query as {
    q?: string;
    locale?: string;
    cityId?: string;
    categorySlug?: string;
    subcategorySlug?: string;
    page?: string | number;
    pageSize?: string | number;
  };

  const result = await catalogService.searchCatalog({
    q,
    locale,
    cityId,
    categorySlug,
    subcategorySlug,
    page: typeof page === "string" ? Number(page) : page,
    pageSize: typeof pageSize === "string" ? Number(pageSize) : pageSize
  });

  response.status(200).json(result);
}

export async function autocompleteCatalogHandler(request: Request, response: Response): Promise<void> {
  const { q, limit, cityId } = request.query as { q: string; limit?: string | number; cityId?: string };
  const result = await catalogService.getAutocompleteSuggestions(
    q,
    typeof limit === "string" ? Number(limit) : limit ?? 12,
    cityId
  );
  response.status(200).json(result);
}

export async function homeCatalogHandler(request: Request, response: Response): Promise<void> {
  const { cityId } = request.query as { cityId?: string };
  const authRequest = request as AuthRequest;
  const result = await catalogService.getHomeCatalog(cityId, authRequest.auth?.userId);
  response.status(200).json(result);
}

export async function trendingCatalogHandler(request: Request, response: Response): Promise<void> {
  const { cityId } = request.query as { cityId?: string };
  const result = await catalogService.getHomeCatalog(cityId);
  response.status(200).json({ items: result.trendingServices });
}

export async function popularCatalogHandler(request: Request, response: Response): Promise<void> {
  const { cityId } = request.query as { cityId?: string };
  const result = await catalogService.getHomeCatalog(cityId);
  response.status(200).json({ items: result.popularServices });
}

export async function recommendedCatalogHandler(request: Request, response: Response): Promise<void> {
  const { cityId } = request.query as { cityId?: string };
  const authRequest = request as AuthRequest;
  const result = await catalogService.getHomeCatalog(cityId, authRequest.auth?.userId);
  response.status(200).json({ items: result.recommendedServices });
}

export async function recentlyBookedCatalogHandler(request: Request, response: Response): Promise<void> {
  const { cityId } = request.query as { cityId?: string };
  const authRequest = request as AuthRequest;
  const result = await catalogService.getHomeCatalog(cityId, authRequest.auth?.userId);
  response.status(200).json({ items: result.recentBookings });
}

export async function createCategoryHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.createCategory(request.body);
  response.status(201).json(result);
}

export async function updateCategoryHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.updateCategory(String(request.params.id), request.body);
  response.status(200).json(result);
}

export async function deleteCategoryHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.updateCategory(String(request.params.id), { isActive: false });
  response.status(200).json(result);
}

export async function reorderCategoriesHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.reorderCategories(request.body.ids);
  response.status(200).json({ categories: result });
}

export async function reorderSubcategoriesHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.reorderSubcategories(request.body.categoryId, request.body.ids);
  response.status(200).json({ subcategories: result });
}

export async function createSubcategoryHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.createSubcategory(request.body);
  response.status(201).json(result);
}

export async function updateSubcategoryHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.updateSubcategory(String(request.params.id), request.body);
  response.status(200).json(result);
}

export async function deleteSubcategoryHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.updateSubcategory(String(request.params.id), { isActive: false });
  response.status(200).json(result);
}

export async function reorderServicesHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.reorderServices(request.body.subcategoryId, request.body.ids);
  response.status(200).json({ services: result });
}

export async function createServiceHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.createService(request.body);
  response.status(201).json(result);
}

export async function updateServiceHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.updateService(String(request.params.id), request.body);
  response.status(200).json(result);
}

export async function deleteServiceHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.updateService(String(request.params.id), { isActive: false });
  response.status(200).json(result);
}

export async function addServiceImagesHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.addServiceImages(String(request.params.id), request.body.images);
  response.status(200).json(result);
}

export async function addServicePricingHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.upsertPriceRule(String(request.params.id), request.body);
  response.status(201).json(result);
}

export async function updatePriceRuleHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.updatePriceRule(String(request.params.id), request.body);
  response.status(200).json(result);
}

export async function importCatalogHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.importCatalog(request.body.categories);
  response.status(201).json(result);
}

export async function exportCatalogHandler(_request: Request, response: Response): Promise<void> {
  const [categories, serviceAreas] = await Promise.all([
    catalogService.resolveAdminCatalogTree(),
    prisma.serviceArea.findMany({
      include: { city: { select: { id: true, name: true } } },
      orderBy: [{ cityId: "asc" }, { name: "asc" }]
    })
  ]);
  response.status(200).json({ categories, serviceAreas });
}

export async function addStarterCatalogHandler(_request: Request, response: Response): Promise<void> {
  const result = await catalogService.addMissingStarterCatalog();
  response.status(200).json(result);
}

export async function bulkCatalogStatusHandler(request: Request, response: Response): Promise<void> {
  const result = await catalogService.bulkSetCatalogActiveStatus(request.body);
  response.status(200).json(result);
}
