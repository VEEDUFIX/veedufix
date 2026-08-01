import { Router } from "express";
import { BookingStatus, PaymentStatus, Prisma } from "@prisma/client";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";

export const adminCustomersRouter = Router();

type AdminBookingRecord = Prisma.BookingGetPayload<{
  include: {
    customer: { select: { name: true } };
    worker: { select: { fullName: true } };
    payments: {
      select: {
        status: true;
        notes: true;
        updatedAt: true;
      };
      orderBy: { updatedAt: "desc" };
      take: 1;
    };
    services: {
      include: {
        service: { select: { name: true } };
        serviceSubcategory: { select: { name: true } };
      };
    };
    address: {
      select: { label: true; line1: true; city: { select: { name: true } } };
    };
  };
}>;

adminCustomersRouter.use(requireAuth, requireRole("ADMIN"));

// ─── List customers ───────────────────────────────────────────────────────────
adminCustomersRouter.get("/", async (request: AuthenticatedRequest, response) => {
  const search = (request.query.search as string) ?? "";

  const customers = await prisma.user.findMany({
    where: {
      role: "CUSTOMER",
      ...(search
        ? {
            OR: [
              { name: { contains: search, mode: "insensitive" as const } },
              { email: { contains: search, mode: "insensitive" as const } },
              { phone: { contains: search } },
            ],
          }
        : {}),
    },
    select: {
      id: true,
      name: true,
      phone: true,
      avatarUrl: true,
      email: true,
      isActive: true,
      createdAt: true,
      _count: { select: { bookings: true } },
    },
    orderBy: { createdAt: "desc" },
    take: 100,
  });

  const serialized = await Promise.all(
    customers.map(async (c) => {
      const totalSpend = await prisma.booking.aggregate({
        where: { customerId: c.id, status: "COMPLETED" },
        _sum: { totalAmount: true },
      });

      return {
        id: c.id,
        name: c.name ?? "Customer",
        phone: c.phone,
        email: c.email ?? null,
        avatarUrl: c.avatarUrl ?? null,
        isActive: c.isActive,
        totalBookings: c._count.bookings,
        totalSpend: Number(totalSpend._sum.totalAmount ?? 0),
        createdAt: c.createdAt.toISOString(),
      };
    })
  );

  response.status(200).json({ customers: serialized });
});

// ─── Ban / Unban customer ─────────────────────────────────────────────────────
adminCustomersRouter.patch("/:customerId/ban", async (request: AuthenticatedRequest, response) => {
  const { customerId } = request.params as { customerId: string };
  const { banned } = request.body as { banned: boolean };

  if (typeof banned !== "boolean") {
    response.status(400).json({ message: "banned must be a boolean" });
    return;
  }

  await prisma.user.update({
    where: { id: customerId },
    data: { isActive: !banned },
  });

  response.status(200).json({ success: true, banned });
});

// ─── Admin bookings ───────────────────────────────────────────────────────────
export const adminBookingsRouter = Router();

adminBookingsRouter.use(requireAuth, requireRole("ADMIN"));

adminBookingsRouter.get("/", async (request: AuthenticatedRequest, response) => {
  const status = (request.query.status as string) ?? "";
  const search = (request.query.search as string) ?? "";

  const bookings = (await prisma.booking.findMany({
    where: {
      ...(status ? { status: status as BookingStatus } : {}),
      ...(search
        ? {
            OR: [
              { id: { contains: search, mode: "insensitive" as const } },
              { code: { contains: search, mode: "insensitive" as const } },
              { customer: { name: { contains: search, mode: "insensitive" as const } } },
              { customer: { phone: { contains: search, mode: "insensitive" as const } } },
              { worker: { fullName: { contains: search, mode: "insensitive" as const } } },
              {
                services: {
                  some: {
                    OR: [
                      { service: { name: { contains: search, mode: "insensitive" as const } } },
                      { serviceSubcategory: { name: { contains: search, mode: "insensitive" as const } } },
                    ],
                  },
                },
              },
            ],
          }
        : {}),
    },
    include: {
      customer: { select: { name: true } },
      worker: { select: { fullName: true } },
      payments: {
        select: {
          status: true,
          notes: true,
          updatedAt: true,
        },
        orderBy: { updatedAt: "desc" },
        take: 1,
      },
      services: {
        include: {
          service: { select: { name: true } },
          serviceSubcategory: { select: { name: true } },
        },
      },
      address: {
        select: { label: true, line1: true, city: { select: { name: true } } },
      },
    },
    orderBy: { createdAt: "desc" },
    take: 100,
  })) as AdminBookingRecord[];

  const serialized = bookings.map((b) => {
    const latestPayment = b.payments[0] ?? null;
    const paymentStatus = latestPayment?.status ?? PaymentStatus.PENDING;
    const paymentNotes =
      latestPayment?.notes && typeof latestPayment.notes === "object" && !Array.isArray(latestPayment.notes)
        ? (latestPayment.notes as Record<string, unknown>)
        : null;
    const paymentRecoveryLabel =
      paymentNotes && (paymentNotes.reconciledBy === "scheduler" || paymentNotes.webhookEvent === "reconciled.order.paid")
        ? "Reconciled"
        : paymentStatus === PaymentStatus.CAPTURED
          ? "Captured"
          : paymentStatus === PaymentStatus.FAILED
            ? "Failed"
            : "Pending";

    return {
      id: b.id,
      code: b.code,
      status: b.status,
      paymentStatus,
      paymentRecoveryLabel,
      customerName: b.customer.name ?? "Customer",
      workerName: b.worker?.fullName ?? null,
      serviceName:
        b.services[0]?.service?.name ??
        b.services[0]?.serviceSubcategory?.name ??
        "Service",
      scheduledAt: b.scheduledAt.toISOString(),
      totalAmount: Number(b.totalAmount),
      addressLabel: b.address
        ? `${b.address.label}, ${b.address.line1}`
        : null
    };
  });

  response.status(200).json({ bookings: serialized });
});
