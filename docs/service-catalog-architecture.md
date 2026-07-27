# VeeduFix Service Catalog Architecture

Brand: VeeduFix
Tagline: We Do Fix.

## Goals

- Support 200+ services without app code changes.
- Let admins manage categories, subcategories, services, images, pricing, SEO, and import/export workflows from one panel.
- Let customers browse, search, favorite, and book services dynamically.
- Let workers choose categories, subcategories, and exact services they can perform.
- Support multilingual content and future city-specific, seasonal, and promotional pricing.

## Data Hierarchy

Category
  - Subcategory
    - Service

Example:

- Home Repair
  - Electrical
    - Switch Replacement
    - Fan Installation
    - Wiring Repair
    - MCB Replacement
    - Door Bell Installation
  - Plumbing
    - Tap Repair
    - Pipe Leakage
    - Water Tank Cleaning
    - Motor Installation
    - Toilet Repair
  - Carpentry
    - Furniture Repair
    - Door Repair
    - Window Repair
    - Modular Kitchen Repair
    - Wardrobe Installation

## Database Design

The Prisma schema is normalized around reusable master tables:

- `ServiceCategory`
- `ServiceSubcategory`
- `Service`
- `ServiceImage`
- `ServiceTranslation`
- `ServiceCategoryTranslation`
- `ServiceSubcategoryTranslation`
- `Skill`
- `Tool`
- `ServiceRequiredSkill`
- `ServiceRequiredTool`
- `ServiceRequiredDocument`
- `ServicePriceRule`
- `WorkerService`
- `ServiceSearchKeyword`
- `CatalogImportJob`

### Why this structure scales

- Categories and subcategories are stable taxonomy records.
- Services are the atomic booking unit and can be created in large volume.
- Translation tables keep multilingual content normalized.
- Pricing rules are separate from the core service record, so city-based and seasonal pricing can be added later without schema churn.
- Worker capabilities are mapped through join tables, allowing one worker to support many services and one service to be offered by many workers.

## Key Prisma Rules

- Category slug is unique.
- Subcategory slug is unique.
- Service slug is unique.
- Localized labels are unique per locale.
- Worker-service mapping is unique per worker and service.
- Search keywords are indexed for autocomplete and typo-friendly lookup.

## Service Fields

Each service should contain:

- Unique ID
- Service name
- Slug
- Category
- Subcategory
- Description
- Starting price
- Estimated duration
- Required skills
- Required tools
- Service images
- Icon
- Active status
- Featured status
- Popular status
- Emergency available
- Home visit
- Warranty days
- GST applicable
- Cancellation policy
- Rating
- Review count
- SEO metadata

## API Design

### Public catalog APIs

- `GET /api/catalog/home`
- `GET /api/catalog/categories`
- `GET /api/catalog/categories/:slug`
- `GET /api/catalog/subcategories/:slug`
- `GET /api/catalog/services/:slug`
- `GET /api/catalog/search?q=&cityId=&locale=`
- `GET /api/catalog/autocomplete?q=&cityId=`
- `GET /api/catalog/trending`
- `GET /api/catalog/popular`
- `GET /api/catalog/recommended`
- `GET /api/catalog/recently-booked`

### Customer APIs

- `GET /api/catalog/favorites`
- `POST /api/catalog/favorites`
- `DELETE /api/catalog/favorites/:serviceId`
- `POST /api/bookings` with selected service and address data

### Worker APIs

- `GET /api/worker/catalog/skills`
- `GET /api/worker/catalog/services`
- `POST /api/worker/catalog/services`
- `PATCH /api/worker/catalog/services/:id`

### Admin APIs

- `POST /api/admin/catalog/categories`
- `PATCH /api/admin/catalog/categories/:id`
- `DELETE /api/admin/catalog/categories/:id`
- `POST /api/admin/catalog/categories/reorder`
- `POST /api/admin/catalog/subcategories`
- `PATCH /api/admin/catalog/subcategories/:id`
- `DELETE /api/admin/catalog/subcategories/:id`
- `POST /api/admin/catalog/services`
- `PATCH /api/admin/catalog/services/:id`
- `DELETE /api/admin/catalog/services/:id`
- `POST /api/admin/catalog/services/:id/images`
- `DELETE /api/admin/catalog/services/:id/images/:imageId`
- `POST /api/admin/catalog/services/:id/pricing-rules`
- `PATCH /api/admin/catalog/pricing-rules/:id`
- `DELETE /api/admin/catalog/pricing-rules/:id`
- `POST /api/admin/catalog/import`
- `GET /api/admin/catalog/import-jobs`
- `GET /api/admin/catalog/export`

## Request Patterns

### Create category

```json
{
  "name": "Home Repair",
  "slug": "home-repair",
  "description": "Core repair and maintenance services",
  "iconUrl": "https://cdn.example.com/icons/home-repair.png",
  "seoTitle": "Home Repair Services in VeeduFix",
  "seoDescription": "Browse professional home repair services"
}
```

### Create service

```json
{
  "categoryId": "cat_123",
  "subcategoryId": "sub_456",
  "name": "Fan Installation",
  "slug": "fan-installation",
  "code": "ELECTRIC-FAN-INSTALL",
  "description": "Professional fan installation with wiring check.",
  "shortDescription": "Safe fan installation",
  "startingPrice": 599,
  "estimatedDurationMins": 45,
  "warrantyDays": 30,
  "gstApplicable": true,
  "emergencyAvailable": false,
  "homeVisit": true,
  "featured": true,
  "popular": true,
  "seoTitle": "Fan Installation Service",
  "seoDescription": "Book certified electricians for fan installation."
}
```

## Admin Workflow

1. Create the main category.
2. Create one or more subcategories under it.
3. Create services under the subcategories.
4. Upload hero and gallery images.
5. Add required skills, tools, and documents.
6. Configure base pricing.
7. Add city-specific pricing overrides if needed.
8. Add seasonal or promotional pricing windows.
9. Mark featured and popular services.
10. Import or export catalog data in bulk.
11. Publish the service to customer and worker apps.

## Customer App Consumption

- Home screen reads dynamic categories, trending services, popular services, recommended services, and recently booked items.
- Search supports service name, category, subcategory, keyword, and location.
- Service details render pricing, duration, images, ratings, and FAQ/SEO content.

## Worker App Consumption

- Workers select categories, subcategories, and exact services they can perform.
- Each service selection can store years of experience, custom pricing, service radius, emergency support, and home-visit availability.

## Search Strategy

- Primary search uses service, category, subcategory, and keywords.
- Autocomplete reads `ServiceSearchKeyword`.
- Trending and popular ranking use service flags plus booking and review counters.
- Location filters combine city, service areas, and city-specific pricing rules.
- Typo tolerance can be added later in the search layer without schema changes.

## Flutter Models

The shared package should expose typed models for:

- Category
- Subcategory
- Service
- Image
- Translation
- Price rule
- Required skill
- Required tool
- Required document

These models should deserialize from the API directly so the app never depends on hardcoded service lists.

## Scaling Notes

- Catalog writes should be admin-only and paginated.
- Public catalog reads should be cached at the API and CDN layer.
- Service images should be stored on Cloudinary.
- Full-text search can later be backed by PostgreSQL trigram indexes or a search engine without changing the app contract.
- All pricing overrides should be append-only or audited so promotions can be tracked cleanly.
