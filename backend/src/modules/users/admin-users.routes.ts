import { Router } from "express";
import { BookingStatus, PaymentStatus, Prisma } from "@prisma/client";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { getBookingTimelineEvents } from "../../lib/booking-timeline.js";

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
        amount: true;
        gateway: true;
        gatewayPaymentId: true;
        gatewayOrderId: true;
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

adminCustomersRouter.get("/:customerId", async (request: AuthenticatedRequest, response) => {
  const { customerId } = request.params as { customerId: string };

  const customer = await prisma.user.findFirst({
    where: {
      id: customerId,
      role: "CUSTOMER"
    },
    select: {
      id: true,
      name: true,
      phone: true,
      avatarUrl: true,
      email: true,
      isActive: true,
      createdAt: true,
      _count: { select: { bookings: true } }
    }
  });

  if (!customer) {
    response.status(404).json({ message: "Customer not found" });
    return;
  }

  const totalSpend = await prisma.booking.aggregate({
    where: { customerId: customer.id, status: "COMPLETED" },
    _sum: { totalAmount: true }
  });

  const recentBookings = await prisma.booking.findMany({
    where: { customerId: customer.id },
    include: {
      worker: { select: { fullName: true } },
      services: {
        include: {
          service: { select: { name: true } },
          serviceSubcategory: { select: { name: true } }
        }
      },
      address: {
        select: { label: true, line1: true, city: { select: { name: true } } }
      }
    },
    orderBy: { createdAt: "desc" },
    take: 10
  });

  response.status(200).json({
    customer: {
      id: customer.id,
      name: customer.name ?? "Customer",
      phone: customer.phone,
      email: customer.email ?? null,
      avatarUrl: customer.avatarUrl ?? null,
      isActive: customer.isActive,
      totalBookings: customer._count.bookings,
      totalSpend: Number(totalSpend._sum.totalAmount ?? 0),
      createdAt: customer.createdAt.toISOString()
    },
    recentBookings: recentBookings.map((booking) => ({
      id: booking.id,
      code: booking.code,
      status: booking.status,
      scheduledAt: booking.scheduledAt.toISOString(),
      totalAmount: Number(booking.totalAmount),
      workerName: booking.worker?.fullName ?? null,
      serviceName:
        booking.services[0]?.service?.name ??
        booking.services[0]?.serviceSubcategory?.name ??
        "Service",
      addressLabel: booking.address ? `${booking.address.label}, ${booking.address.line1}` : null
    }))
  });
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

adminBookingsRouter.get("/:bookingId", async (request: AuthenticatedRequest, response) => {
  const { bookingId } = request.params as { bookingId: string };

  const booking = (await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      customer: { select: { id: true, name: true, phone: true, avatarUrl: true } },
      worker: { select: { id: true, fullName: true } },
      payments: {
        select: {
          status: true,
          notes: true,
          updatedAt: true,
          amount: true,
          gateway: true,
          gatewayPaymentId: true,
          gatewayOrderId: true
        },
        orderBy: { updatedAt: "desc" },
        take: 5
      },
      services: {
        include: {
          service: { select: { id: true, name: true, iconUrl: true, slug: true } },
          serviceSubcategory: { select: { id: true, name: true, slug: true } }
        }
      },
      address: {
        select: {
          id: true,
          label: true,
          line1: true,
          city: { select: { id: true, name: true } }
        }
      }
    }
  })) as AdminBookingRecord | null;

  if (!booking) {
    response.status(404).json({ message: "Booking not found" });
    return;
  }

  const latestPayment = booking.payments[0] ?? null;
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

  response.status(200).json({
    booking: {
      id: booking.id,
      code: booking.code,
      status: booking.status,
      paymentStatus,
      paymentRecoveryLabel,
      customer: booking.customer,
      worker: booking.worker,
      serviceName:
        booking.services[0]?.service?.name ??
        booking.services[0]?.serviceSubcategory?.name ??
        "Service",
      scheduledAt: booking.scheduledAt.toISOString(),
      totalAmount: Number(booking.totalAmount),
      address: booking.address
        ? {
            id: booking.address.id,
            label: booking.address.label,
            line1: booking.address.line1,
            cityName: booking.address.city?.name ?? null
          }
        : null,
      payments: booking.payments.map((payment: AdminBookingRecord["payments"][number]) => ({
        status: payment.status,
        amount: Number(payment.amount),
        gateway: payment.gateway,
        gatewayPaymentId: payment.gatewayPaymentId,
        gatewayOrderId: payment.gatewayOrderId,
        updatedAt: payment.updatedAt.toISOString()
      })),
      services: booking.services.map((bookingService: AdminBookingRecord["services"][number]) => ({
        id: bookingService.id,
        serviceName: bookingService.service?.name ?? bookingService.serviceSubcategory?.name ?? "Service",
        serviceId: bookingService.service?.id ?? null,
        serviceSlug: bookingService.service?.slug ?? bookingService.serviceSubcategory?.slug ?? null
      })),
      timeline: (await getBookingTimelineEvents(booking.id)).map((event) => ({
        id: event.id,
        status: event.status,
        title: event.title,
        description: event.description,
        createdAt: event.createdAt.toISOString()
      }))
    }
  });
});

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
