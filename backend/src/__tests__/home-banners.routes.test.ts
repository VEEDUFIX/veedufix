import express from "express";
import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../lib/prisma.js", () => ({
  prisma: {
    homeBanner: {
      create: vi.fn(),
      findMany: vi.fn(),
      findUnique: vi.fn(),
      update: vi.fn(),
    },
    $transaction: vi.fn(),
    service: { findFirst: vi.fn(), findMany: vi.fn() },
    serviceCategory: { findFirst: vi.fn(), findMany: vi.fn() },
  },
}));

vi.mock("../middleware/auth.js", () => ({
  requireAuth: (req: express.Request, res: express.Response, next: express.NextFunction) => {
    const authorization = req.headers.authorization;
    if (authorization !== "Bearer admin" && authorization !== "Bearer worker") {
      res.status(401).json({ message: "Missing or invalid bearer token" });
      return;
    }
    (req as express.Request & { auth?: { role: string } }).auth = {
      role: authorization === "Bearer admin" ? "ADMIN" : "WORKER",
    };
    next();
  },
  requireRole: (...roles: string[]) => (
    req: express.Request & { auth?: { role: string } },
    res: express.Response,
    next: express.NextFunction,
  ) => {
    if (!req.auth || !roles.includes(req.auth.role)) {
      res.status(403).json({ message: "Insufficient permissions" });
      return;
    }
    next();
  },
}));

vi.mock("../modules/catalog/catalog.service.js", () => ({
  catalogService: { resolveHomeServiceSections: vi.fn() },
  publicServiceEligibility: () => ({ isActive: true }),
}));

import { prisma } from "../lib/prisma.js";
import { adminHomeBannersRouter } from "../modules/catalog/home-banners.routes.js";

const app = express();
app.use(express.json());
app.use("/api/admin/catalog", adminHomeBannersRouter);

const bannerBody = {
  imageUrl: "https://res.cloudinary.com/veedufix/image/upload/banner.jpg",
  destinationType: "category",
  destinationValue: "",
  sortOrder: 0,
  isActive: true,
  startsAt: null,
  endsAt: null,
};

describe("Admin home banner routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.homeBanner.create).mockImplementation(async ({ data }) => ({
      id: "banner-1",
      ...data,
    }) as never);
    vi.mocked(prisma.homeBanner.findUnique).mockResolvedValue({
      id: "banner-1",
      ...bannerBody,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as never);
    vi.mocked(prisma.homeBanner.findMany).mockResolvedValue([
      { id: "banner-1" },
      { id: "banner-2" },
    ] as never);
    vi.mocked(prisma.$transaction).mockImplementation(async (operations) =>
      Promise.all(operations as Promise<unknown>[]),
    );
    vi.mocked(prisma.homeBanner.update).mockImplementation(async ({ data }) => ({
      id: "banner-1",
      ...bannerBody,
      ...data,
    }) as never);
    vi.mocked(prisma.service.findFirst).mockResolvedValue({ id: "service-1" } as never);
    vi.mocked(prisma.serviceCategory.findFirst).mockResolvedValue({ id: "category-1" } as never);
    vi.mocked(prisma.service.findMany).mockResolvedValue([{
      id: "service-1", name: "Switch repair", slug: "switch-repair", category: { name: "Electrical" },
    }] as never);
    vi.mocked(prisma.serviceCategory.findMany).mockResolvedValue([{
      id: "category-1", name: "Electrical", slug: "electrical",
    }] as never);
  });

  it("provides active category and eligible service choices to Admin", async () => {
    const response = await request(app)
      .get("/api/admin/catalog/home-banner-destinations")
      .set("Authorization", "Bearer admin");

    expect(response.status).toBe(200);
    expect(response.body.categories).toEqual([
      expect.objectContaining({ name: "Electrical", slug: "electrical" }),
    ]);
    expect(response.body.services).toEqual([
      expect.objectContaining({ name: "Switch repair", slug: "switch-repair" }),
    ]);
    expect(prisma.service.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ isActive: true }),
    }));
  });

  it("creates a general Category-search banner without a category slug", async () => {
    const response = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send(bannerBody);

    expect(response.status).toBe(201);
    expect(response.body.banner).toMatchObject({
      destinationType: "category",
      destinationValue: "",
      imageUrl: bannerBody.imageUrl,
    });
    expect(prisma.serviceCategory.findFirst).not.toHaveBeenCalled();
    expect(prisma.homeBanner.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ destinationType: "category", destinationValue: "" }),
    });
  });

  it("creates a category search for an active catalog category", async () => {
    const response = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send({ ...bannerBody, destinationValue: "electrical" });

    expect(response.status).toBe(201);
    expect(prisma.serviceCategory.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ slug: "electrical", isActive: true }),
    }));
  });

  it("creates a Service-page banner only when the slug resolves to an eligible service", async () => {
    const response = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send({ ...bannerBody, destinationType: "service", destinationValue: "switch-repair" });

    expect(response.status).toBe(201);
    expect(prisma.service.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ slug: "switch-repair", isActive: true }),
    }));
  });

  it("rejects a nonexistent service slug and an unsupported custom route", async () => {
    vi.mocked(prisma.service.findFirst).mockResolvedValueOnce(null as never);
    const invalidService = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send({ ...bannerBody, destinationType: "service", destinationValue: "missing-service" });
    expect(invalidService.status).toBe(400);
    expect(invalidService.body.message).toContain("destination was not found");

    const invalidRoute = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send({ ...bannerBody, destinationType: "custom_route", destinationValue: "/not-a-customer-route" });
    expect(invalidRoute.status).toBe(400);
    expect(invalidRoute.body.issues).toEqual(expect.arrayContaining([
      expect.objectContaining({ path: "body.destinationValue" }),
    ]));
    expect(prisma.homeBanner.create).not.toHaveBeenCalled();
  });

  it("rejects a category that is no longer available", async () => {
    vi.mocked(prisma.serviceCategory.findFirst).mockResolvedValueOnce(null as never);
    const response = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send({ ...bannerBody, destinationValue: "retired-category" });

    expect(response.status).toBe(400);
    expect(response.body.message).toContain("destination was not found");
    expect(prisma.homeBanner.create).not.toHaveBeenCalled();
  });

  it("allows supported internal routes and preserves Admin authorization", async () => {
    const allowedRoute = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send({ ...bannerBody, destinationType: "custom_route", destinationValue: "/search?q=cleaning" });
    expect(allowedRoute.status).toBe(201);

    const unauthenticated = await request(app)
      .post("/api/admin/catalog/home-banners")
      .send(bannerBody);
    expect(unauthenticated.status).toBe(401);

    const unauthorizedRole = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer worker")
      .send(bannerBody);
    expect(unauthorizedRole.status).toBe(403);
  });

  it("updates an existing banner with a blank general category destination", async () => {
    const response = await request(app)
      .patch("/api/admin/catalog/home-banners/banner-1")
      .set("Authorization", "Bearer admin")
      .send({ destinationType: "category", destinationValue: "" });

    expect(response.status).toBe(200);
    expect(prisma.homeBanner.update).toHaveBeenCalledWith({
      where: { id: "banner-1" },
      data: expect.objectContaining({ destinationType: "category", destinationValue: "" }),
    });
  });

  it("persists publish state and order changes through the update route", async () => {
    const response = await request(app)
      .patch("/api/admin/catalog/home-banners/banner-1")
      .set("Authorization", "Bearer admin")
      .send({ isActive: false, sortOrder: 3 });

    expect(response.status).toBe(200);
    expect(prisma.homeBanner.update).toHaveBeenCalledWith({
      where: { id: "banner-1" },
      data: expect.objectContaining({ isActive: false, sortOrder: 3 }),
    });
  });

  it("reorders banners in one transaction and rejects unknown or duplicate IDs", async () => {
    const response = await request(app)
      .post("/api/admin/catalog/home-banners/reorder")
      .set("Authorization", "Bearer admin")
      .send({ ids: ["banner-2", "banner-1"] });

    expect(response.status).toBe(200);
    expect(prisma.$transaction).toHaveBeenCalledOnce();
    expect(prisma.homeBanner.update).toHaveBeenCalledWith({
      where: { id: "banner-2" },
      data: { sortOrder: 0 },
    });
    expect(prisma.homeBanner.update).toHaveBeenCalledWith({
      where: { id: "banner-1" },
      data: { sortOrder: 1 },
    });

    vi.mocked(prisma.homeBanner.findMany).mockResolvedValueOnce([] as never);
    const unknownId = await request(app)
      .post("/api/admin/catalog/home-banners/reorder")
      .set("Authorization", "Bearer admin")
      .send({ ids: ["missing-banner"] });
    expect(unknownId.status).toBe(400);
    expect(prisma.$transaction).toHaveBeenCalledOnce();

    const duplicateId = await request(app)
      .post("/api/admin/catalog/home-banners/reorder")
      .set("Authorization", "Bearer admin")
      .send({ ids: ["banner-1", "banner-1"] });
    expect(duplicateId.status).toBe(400);
    expect(prisma.$transaction).toHaveBeenCalledOnce();
  });

  it("rejects invalid display order and reversed dates", async () => {
    const invalidOrder = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send({ ...bannerBody, sortOrder: -1 });
    expect(invalidOrder.status).toBe(400);

    const invalidDates = await request(app)
      .post("/api/admin/catalog/home-banners")
      .set("Authorization", "Bearer admin")
      .send({
        ...bannerBody,
        startsAt: "2026-10-22T00:00:00.000Z",
        endsAt: "2026-10-21T00:00:00.000Z",
      });
    expect(invalidDates.status).toBe(400);
  });
});
