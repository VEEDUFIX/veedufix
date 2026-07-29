import { Router } from "express";
import { requireAuth, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { serializeWorkerProfile } from "../worker-onboarding/worker-onboarding.service.js";

export const usersRouter = Router();

// Notifications endpoint
usersRouter.get("/notifications", requireAuth, async (request: AuthenticatedRequest, response) => {
  const notifications = await prisma.notification.findMany({
    where: { userId: request.auth!.userId },
    orderBy: { createdAt: "desc" },
    take: 50
  });

  response.status(200).json({ notifications: notifications.map((n: any) => ({
    id: n.id,
    type: n.type,
    title: n.title,
    body: n.body,
    isRead: n.isRead,
    data: n.data,
    createdAt: n.createdAt.toISOString()
  })) });
});

// ─── Current user profile ────────────────────────────────────────────────────
usersRouter.get("/me", requireAuth, async (request: AuthenticatedRequest, response) => {
  const user = await prisma.user.findUnique({
    where: { id: request.auth!.userId },
    include: {
      city: true,
      workerProfile: true,
      addresses: true
    }
  });

  if (!user) {
    response.status(404).json({ message: "User not found" });
    return;
  }

  response.status(200).json({
    user: {
      ...user,
      workerProfile: user.workerProfile ? serializeWorkerProfile(user.workerProfile) : null
    }
  });
});

// ─── Customer: list my bookings ───────────────────────────────────────────────
// Query param: ?status=upcoming|completed|cancelled
usersRouter.get("/me/bookings", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const tab = (request.query.status as string) ?? "upcoming";

  let statusFilter: any[];
  if (tab === "completed") {
    statusFilter = ["COMPLETED"];
  } else if (tab === "cancelled") {
    statusFilter = ["CANCELLED", "REFUNDED", "CANCELLED_MANUAL", "CANCELLED_NO_SHOW"];
  } else {
    statusFilter = ["PENDING", "ACCEPTED", "WORKER_ASSIGNED", "EN_ROUTE", "ARRIVED", "IN_PROGRESS"];
  }

  const bookings = await prisma.booking.findMany({
    where: {
      customerId: userId,
      status: { in: statusFilter }
    },
    orderBy: { scheduledAt: "desc" },
    include: {
      services: {
        include: {
          service: { select: { name: true, iconUrl: true, slug: true } },
          serviceSubcategory: { select: { name: true } }
        }
      },
      worker: {
        select: {
          id: true,
          fullName: true,
          averageRating: true,
          user: { select: { avatarUrl: true } }
        }
      },
      address: {
        select: { label: true, line1: true, city: { select: { name: true } } }
      }
    }
  });

  const serialized = bookings.map((b) => ({
    id: b.id,
    code: b.code,
    status: b.status,
    scheduledAt: b.scheduledAt.toISOString(),
    totalAmount: Number(b.totalAmount),
    serviceName: b.services[0]?.service?.name ?? b.services[0]?.serviceSubcategory?.name ?? "Service",
    serviceIcon: b.services[0]?.service?.iconUrl ?? null,
    serviceSlug: b.services[0]?.service?.slug ?? null,
    addressLabel: b.address ? `${b.address.label}, ${b.address.line1}` : null,
    cityName: b.address?.city?.name ?? null,
    worker: b.worker
      ? {
          id: b.worker.id,
          name: b.worker.fullName ?? "Professional",
          rating: Number(b.worker.averageRating),
          avatarUrl: b.worker.user?.avatarUrl ?? null
        }
      : null
  }));

  response.status(200).json({ bookings: serialized });
});

// ─── Worker: list my jobs ─────────────────────────────────────────────────────
// Query param: ?tab=incoming|accepted|active|completed
usersRouter.get("/me/worker/jobs", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const tab = (request.query.tab as string) ?? "incoming";

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  if (tab === "incoming") {
    const offers = await prisma.dispatchOffer.findMany({
      where: {
        workerId: workerProfile.id,
        status: "pending"
      },
      include: {
        booking: {
          include: {
            services: {
              include: {
                service: { select: { name: true, iconUrl: true } },
                serviceSubcategory: { select: { name: true } }
              }
            },
            address: {
              select: { label: true, line1: true, city: { select: { name: true } } }
            }
          }
        }
      },
      orderBy: { expiresAt: "asc" }
    });

    const incomingJobs = offers.map((o) => ({
      offerId: o.id,
      bookingId: o.bookingId,
      code: o.booking.code,
      status: "PENDING",
      scheduledAt: o.booking.scheduledAt.toISOString(),
      totalAmount: Number(o.booking.totalAmount),
      expiresAt: o.expiresAt.toISOString(),
      serviceName: o.booking.services[0]?.service?.name ?? o.booking.services[0]?.serviceSubcategory?.name ?? "Service",
      serviceIcon: o.booking.services[0]?.service?.iconUrl ?? null,
      addressLabel: o.booking.address
        ? `${o.booking.address.label}, ${o.booking.address.line1}`
        : null,
      cityName: o.booking.address?.city?.name ?? null
    }));

    response.status(200).json({ jobs: incomingJobs });
    return;
  }

  let statusFilter: any[];
  if (tab === "accepted") {
    statusFilter = ["WORKER_ASSIGNED", "ACCEPTED"];
  } else if (tab === "active") {
    statusFilter = ["IN_PROGRESS", "ARRIVED", "EN_ROUTE"];
  } else {
    statusFilter = ["COMPLETED"];
  }

  const bookings = await prisma.booking.findMany({
    where: {
      workerId: workerProfile.id,
      status: { in: statusFilter }
    },
    orderBy: { scheduledAt: "desc" },
    include: {
      services: {
        include: {
          service: { select: { name: true, iconUrl: true } },
          serviceSubcategory: { select: { name: true } }
        }
      },
      customer: { select: { name: true, avatarUrl: true } },
      address: {
        select: { label: true, line1: true, city: { select: { name: true } } }
      }
    }
  });

  const serialized = bookings.map((b) => ({
    bookingId: b.id,
    code: b.code,
    status: b.status,
    scheduledAt: b.scheduledAt.toISOString(),
    totalAmount: Number(b.totalAmount),
    serviceName: b.services[0]?.service?.name ?? b.services[0]?.serviceSubcategory?.name ?? "Service",
    serviceIcon: b.services[0]?.service?.iconUrl ?? null,
    customerName: b.customer.name ?? "Customer",
    customerAvatarUrl: b.customer.avatarUrl ?? null,
    addressLabel: b.address
      ? `${b.address.label}, ${b.address.line1}`
      : null,
    cityName: b.address?.city?.name ?? null
  }));

  response.status(200).json({ jobs: serialized });
});

// ─── Worker: dashboard stats ──────────────────────────────────────────────────
usersRouter.get("/me/worker/stats", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: {
      id: true,
      completedJobsCount: true,
      averageRating: true,
      isAvailable: true
    }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  const startOfMonth = new Date();
  startOfMonth.setDate(1);
  startOfMonth.setHours(0, 0, 0, 0);

  const monthlyEarnings = await prisma.walletTransaction.aggregate({
    where: {
      workerId: workerProfile.id,
      type: "CREDIT",
      createdAt: { gte: startOfMonth }
    },
    _sum: { amount: true }
  });

  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date();
  endOfDay.setHours(23, 59, 59, 999);

  const todayJobs = await prisma.booking.findMany({
    where: {
      workerId: workerProfile.id,
      status: { in: ["WORKER_ASSIGNED", "IN_PROGRESS", "ARRIVED", "EN_ROUTE", "ACCEPTED"] as any[] },
      scheduledAt: { gte: startOfDay, lte: endOfDay }
    },
    include: {
      services: {
        include: {
          service: { select: { name: true, iconUrl: true } },
          serviceSubcategory: { select: { name: true } }
        }
      },
      address: { select: { label: true, line1: true } }
    },
    orderBy: { scheduledAt: "asc" },
    take: 5
  });

  response.status(200).json({
    stats: {
      completedJobsCount: workerProfile.completedJobsCount,
      averageRating: Number(workerProfile.averageRating),
      monthlyEarnings: Number(monthlyEarnings._sum.amount ?? 0),
      isAvailable: workerProfile.isAvailable
    },
    todayJobs: todayJobs.map((j) => ({
      bookingId: j.id,
      code: j.code,
      status: j.status,
      scheduledAt: j.scheduledAt.toISOString(),
      serviceName: j.services[0]?.service?.name ?? j.services[0]?.serviceSubcategory?.name ?? "Service",
      serviceIcon: j.services[0]?.service?.iconUrl ?? null,
      addressLabel: j.address ? `${j.address.label}, ${j.address.line1}` : null
    }))
  });
});

// ─── Booking summary (for chat header / tracking page) ────────────────────────
usersRouter.get("/bookings/:bookingId/summary", requireAuth, async (request: AuthenticatedRequest, response) => {
  const { bookingId } = request.params;
  const userId = request.auth!.userId;

  const booking = await prisma.booking.findUnique({
    where: { id: bookingId as string },
    include: {
      worker: {
        select: {
          id: true,
          fullName: true,
          averageRating: true,
          user: { select: { avatarUrl: true } }
        }
      },
      customer: { select: { id: true, name: true, avatarUrl: true } }
    }
  });

  if (!booking) {
    response.status(404).json({ message: "Booking not found" });
    return;
  }

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  const isCustomer = booking.customerId === userId;
  const isWorker = workerProfile != null && booking.workerId === workerProfile.id;

  if (!isCustomer && !isWorker) {
    response.status(403).json({ message: "Forbidden" });
    return;
  }

  response.status(200).json({
    bookingId: booking.id,
    code: booking.code,
    status: booking.status,
    worker: booking.worker
      ? {
          id: booking.worker.id,
          name: booking.worker.fullName ?? "Professional",
          avatarUrl: booking.worker.user?.avatarUrl ?? null,
          rating: Number(booking.worker.averageRating)
        }
      : null,
    customer: {
      name: booking.customer.name ?? "Customer",
      avatarUrl: booking.customer.avatarUrl ?? null
    }
  });
});

// ─── Public worker profile ────────────────────────────────────────────────────
usersRouter.get("/workers/:workerId/profile", async (request, response) => {
  const { workerId } = request.params;

  const profile = await prisma.workerProfile.findUnique({
    where: { id: workerId },
    include: {
      user: { select: { id: true, name: true, avatarUrl: true, phone: true } },
      skills: {
        include: { category: { select: { name: true, slug: true } } },
        take: 10
      },
      portfolioPhotos: { orderBy: { createdAt: "desc" as const }, take: 12 },
      reviews: {
        orderBy: { createdAt: "desc" as const },
        take: 10,
        include: { reviewer: { select: { name: true, avatarUrl: true } } }
      }
    }
  });

  if (!profile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  response.status(200).json({
    profile: {
      id: profile.id,
      displayName: profile.fullName ?? profile.user.name ?? "Professional",
      avatarUrl: profile.user.avatarUrl ?? null,
      bio: profile.bio ?? null,
      averageRating: Number(profile.averageRating),
      completedJobsCount: profile.completedJobsCount,
      experienceYears: profile.experienceYears,
      isAvailable: profile.isAvailable,
      verificationStatus: profile.verificationStatus,
      skills: profile.skills.map((s) => ({
        id: s.id,
        categoryName: s.category.name,
        categorySlug: s.category.slug
      })),
      portfolioPhotos: profile.portfolioPhotos.map((p) => ({
        id: p.id,
        url: p.url,
        caption: p.caption ?? null
      })),
      reviews: profile.reviews.map((r) => ({
        id: r.id,
        rating: r.rating,
        comment: r.comment ?? null,
        customerName: r.reviewer?.name ?? "Customer",
        customerAvatarUrl: r.reviewer?.avatarUrl ?? null,
        createdAt: r.createdAt.toISOString()
      }))
    }
  });
});
