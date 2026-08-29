import { Router } from "express";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { writeAuditLog } from "../../lib/audit.js";

export const adminCouponsRouter = Router();

adminCouponsRouter.use(requireAuth, requireRole("ADMIN"));

// List all coupons
adminCouponsRouter.get("/", async (_request, response) => {
  const coupons = await prisma.coupon.findMany({
    orderBy: { createdAt: "desc" },
  });
  response.status(200).json({
    coupons: coupons.map((c) => ({
      id: c.id,
      code: c.code,
      description: c.description ?? null,
      type: c.type,
      value: Number(c.value),
      minOrderAmount: c.minOrderAmount ? Number(c.minOrderAmount) : null,
      maxDiscount: c.maxDiscount ? Number(c.maxDiscount) : null,
      startsAt: c.startsAt?.toISOString() ?? null,
      endsAt: c.endsAt?.toISOString() ?? null,
      usageLimit: c.usageLimit ?? null,
      perUserLimit: c.perUserLimit ?? 1,
      isActive: c.isActive,
      createdAt: c.createdAt.toISOString(),
    })),
  });
});

// Create coupon
adminCouponsRouter.post("/", async (request: AuthenticatedRequest, response) => {
  const body = request.body as {
    code: string;
    description?: string;
    type: string;
    value: number;
    minOrderAmount?: number;
    maxDiscount?: number;
    startsAt?: string;
    endsAt?: string;
    usageLimit?: number;
    perUserLimit?: number;
  };

  if (!body.code || !body.type || body.value == null) {
    response.status(400).json({ message: "code, type, and value are required" });
    return;
  }

  const existing = await prisma.coupon.findUnique({ where: { code: body.code.toUpperCase() } });
  if (existing) {
    response.status(409).json({ message: "Coupon code already exists" });
    return;
  }

  const coupon = await prisma.coupon.create({
    data: {
      code: body.code.toUpperCase(),
      description: body.description,
      type: body.type as any,
      value: body.value,
      minOrderAmount: body.minOrderAmount,
      maxDiscount: body.maxDiscount,
      startsAt: body.startsAt ? new Date(body.startsAt) : null,
      endsAt: body.endsAt ? new Date(body.endsAt) : null,
      usageLimit: body.usageLimit,
      perUserLimit: body.perUserLimit ?? 1,
    },
  });

  void writeAuditLog({
    adminId: request.auth!.userId,
    action: "coupon.created",
    targetType: "coupon",
    targetId: coupon.id,
    note: `Created coupon ${coupon.code}`,
    metadata: {
      code: coupon.code,
      type: coupon.type,
      value: Number(coupon.value),
      isActive: coupon.isActive
    }
  });

  response.status(201).json({ coupon });
});

// Toggle active
adminCouponsRouter.patch("/:id/toggle", async (request: AuthenticatedRequest, response) => {
  const { id } = request.params as { id: string };
  const coupon = await prisma.coupon.findUnique({ where: { id } });
  if (!coupon) {
    response.status(404).json({ message: "Coupon not found" });
    return;
  }
  const updated = await prisma.coupon.update({
    where: { id },
    data: { isActive: !coupon.isActive },
  });

  void writeAuditLog({
    adminId: request.auth!.userId,
    action: "coupon.updated",
    targetType: "coupon",
    targetId: id,
    note: updated.isActive ? "Coupon activated" : "Coupon deactivated",
    metadata: {
      code: coupon.code,
      isActive: updated.isActive
    }
  });

  response.status(200).json({ isActive: updated.isActive });
});

// Delete coupon
adminCouponsRouter.delete("/:id", async (request: AuthenticatedRequest, response) => {
  const { id } = request.params as { id: string };
  const coupon = await prisma.coupon.findUnique({ where: { id } });
  await prisma.coupon.delete({ where: { id } });

  if (coupon) {
    void writeAuditLog({
      adminId: request.auth!.userId,
      action: "coupon.deleted",
      targetType: "coupon",
      targetId: id,
      note: `Deleted coupon ${coupon.code}`,
      metadata: {
        code: coupon.code,
        type: coupon.type
      }
    });
  }

  response.status(200).json({ success: true });
});
