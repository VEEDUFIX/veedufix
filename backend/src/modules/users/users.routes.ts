import { Router } from "express";
import { requireAuth, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { getBookingTimelineEvents } from "../../lib/booking-timeline.js";
import { serializeWorkerProfile } from "../worker-onboarding/worker-onboarding.service.js";

export const usersRouter = Router();

function serializeNotification(notification: {
  id: string;
  type: string;
  title: string;
  body: string;
  isRead: boolean;
  data: unknown;
  createdAt: Date;
}) {
  return {
    id: notification.id,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    isRead: notification.isRead,
    data: notification.data,
    createdAt: notification.createdAt.toISOString()
  };
}

// Notifications endpoint
usersRouter.get("/notifications", requireAuth, async (request: AuthenticatedRequest, response) => {
  const [notifications, unreadCount] = await Promise.all([
    prisma.notification.findMany({
      where: { userId: request.auth!.userId },
      orderBy: { createdAt: "desc" },
      take: 50
    }),
    prisma.notification.count({
      where: { userId: request.auth!.userId, isRead: false }
    })
  ]);

  response.status(200).json({
    notifications: notifications.map((notification: any) => serializeNotification(notification)),
    unreadCount
  });
});

usersRouter.post("/notifications/mark-all-read", requireAuth, async (request: AuthenticatedRequest, response) => {
  const result = await prisma.notification.updateMany({
    where: { userId: request.auth!.userId, isRead: false },
    data: { isRead: true }
  });

  response.status(200).json({ updated: result.count });
});

usersRouter.patch("/notifications/:notificationId/read", requireAuth, async (request: AuthenticatedRequest, response) => {
  const notificationId = String(request.params.notificationId);

  const notification = await prisma.notification.findFirst({
    where: {
      id: notificationId,
      userId: request.auth!.userId
    }
  });

  if (!notification) {
    response.status(404).json({ message: "Notification not found" });
    return;
  }

  const updated = await prisma.notification.update({
    where: { id: notificationId },
    data: { isRead: true }
  });

  response.status(200).json({ notification: serializeNotification(updated) });
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

// ─── Customer: Download Invoice PDF ──────────────────────────────────────────
usersRouter.get("/bookings/:bookingId/invoice/pdf", requireAuth, async (request: AuthenticatedRequest, response) => {
  const { bookingId } = request.params as { bookingId: string };
  const userId = request.auth!.userId;

  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      customer: true,
      services: {
        include: {
          service: true,
          serviceSubcategory: true
        }
      },
      worker: { include: { user: true } },
      payments: true
    }
  });

  if (!booking) {
    response.status(404).json({ message: "Booking not found" });
    return;
  }

  // Ensure the user owns this booking
  if (booking.customerId !== userId) {
    response.status(403).json({ message: "Access denied" });
    return;
  }

  try {
    // We dynamically import to avoid loading pdfkit unless this route is hit
    const { generateInvoicePdf } = await import("../bookings/pdf.service.js");
    const pdfBuffer = await generateInvoicePdf(booking);

    response.setHeader("Content-Type", "application/pdf");
    response.setHeader("Content-Disposition", `attachment; filename=Invoice-${booking.code}.pdf`);
    response.send(pdfBuffer);
  } catch (error) {
    response.status(500).json({ error: "Failed to generate PDF" });
  }
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
      serviceId: o.booking.services[0]?.service?.id ?? null,
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
      serviceId: b.services[0]?.service?.id ?? null,
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
      serviceId: j.services[0]?.service?.id ?? null,
      serviceName: j.services[0]?.service?.name ?? j.services[0]?.serviceSubcategory?.name ?? "Service",
      serviceIcon: j.services[0]?.service?.iconUrl ?? null,
      addressLabel: j.address ? `${j.address.label}, ${j.address.line1}` : null
    }))
  });
});

// ─── Single booking full detail ───────────────────────────────────────────────
usersRouter.get("/bookings/:bookingId", requireAuth, async (request: AuthenticatedRequest, response) => {
  const { bookingId } = request.params as { bookingId: string };
  const userId = request.auth!.userId;

  const booking = await prisma.booking.findUnique({
    where: { id: bookingId as string },
    include: {
      services: {
        include: {
          service: { select: { name: true, iconUrl: true, slug: true } },
          serviceSubcategory: { select: { name: true } },
        },
      },
      worker: {
        select: {
          id: true,
          fullName: true,
          averageRating: true,
          user: { select: { avatarUrl: true } },
        },
      },
      address: {
        select: { label: true, line1: true, city: { select: { name: true } } },
      },
      sparePartRequest: true,
    },
  });

  if (!booking) {
    response.status(404).json({ message: "Booking not found" });
    return;
  }

  if (booking.customerId !== userId) {
    response.status(403).json({ message: "Forbidden" });
    return;
  }

  response.status(200).json({
    booking: {
      id: booking.id,
      code: booking.code,
      status: booking.status,
      scheduledAt: booking.scheduledAt.toISOString(),
      totalAmount: Number(booking.totalAmount),
      serviceName: booking.services[0]?.service?.name ?? booking.services[0]?.serviceSubcategory?.name ?? "Service",
      serviceIcon: booking.services[0]?.service?.iconUrl ?? null,
      serviceSlug: booking.services[0]?.service?.slug ?? null,
      addressLabel: booking.address
        ? `${booking.address.label}, ${booking.address.line1}, ${booking.address.city?.name ?? ""}`
        : null,
      worker: booking.worker
        ? {
            id: booking.worker.id,
            name: booking.worker.fullName ?? "Professional",
            rating: Number(booking.worker.averageRating),
            avatarUrl: booking.worker.user?.avatarUrl ?? null,
          }
        : null,
      // Custom quote fields
      customQuoteStatus: booking.customQuoteStatus ?? null,
      customQuoteAmount: booking.customQuoteAmount ? Number(booking.customQuoteAmount) : null,
      customQuoteItemized: booking.customQuoteItemized ?? null,
      customQuoteNotes: booking.customQuoteNotes ?? null,
      // Spare parts fields
      sparePartStatus: booking.sparePartRequest?.status ?? null,
      sparePartTotal: booking.sparePartRequest ? Number(booking.sparePartRequest.totalAmount) : null,
      sparePartItems: booking.sparePartRequest?.items ?? null,
      sparePartReceiptUrl: booking.sparePartRequest?.receiptPhotoUrl ?? null,
      timeline: (await getBookingTimelineEvents(booking.id)).map((event) => ({
        id: event.id,
        status: event.status,
        title: event.title,
        description: event.description,
        createdAt: event.createdAt.toISOString()
      }))
    },
  });
});

usersRouter.patch("/bookings/:bookingId", requireAuth, async (request: AuthenticatedRequest, response) => {
  const { bookingId } = request.params as { bookingId: string };
  const userId = request.auth!.userId;
  const { addressId, scheduledAt } = request.body as { addressId?: string; scheduledAt?: string };

  if (!addressId && !scheduledAt) {
    response.status(400).json({ message: "addressId or scheduledAt is required" });
    return;
  }

  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      customerId: true,
      status: true,
      workerId: true,
      addressId: true,
      cityId: true,
      scheduledAt: true,
      dispatchOffers: {
        where: { status: "pending" },
        select: { id: true }
      }
    }
  });

  if (!booking) {
    response.status(404).json({ message: "Booking not found" });
    return;
  }

  if (booking.customerId !== userId) {
    response.status(403).json({ message: "Access denied" });
    return;
  }

  if (booking.status !== "PENDING" || booking.workerId != null || booking.dispatchOffers.length > 0) {
    response.status(409).json({ message: "Booking can only be modified before dispatch" });
    return;
  }

  let nextAddressId = booking.addressId;
  let nextCityId = booking.cityId;
  if (addressId) {
    const address = await prisma.address.findFirst({
      where: { id: addressId, userId },
      select: { id: true, cityId: true }
    });
    if (!address) {
      response.status(404).json({ message: "Address not found" });
      return;
    }
    nextAddressId = address.id;
    nextCityId = address.cityId;
  }

  let nextScheduledAt = booking.scheduledAt;
  if (scheduledAt) {
    const parsed = new Date(scheduledAt);
    if (Number.isNaN(parsed.getTime())) {
      response.status(400).json({ message: "scheduledAt is invalid" });
      return;
    }
    nextScheduledAt = parsed;
  }

  const updated = await prisma.booking.update({
    where: { id: booking.id },
    data: {
      addressId: nextAddressId,
      cityId: nextCityId,
      scheduledAt: nextScheduledAt,
      scheduledFor: nextScheduledAt
    },
    include: {
      address: {
        select: { label: true, line1: true, city: { select: { name: true } } }
      }
    }
  });

  response.status(200).json({
    success: true,
    booking: {
      id: updated.id,
      addressLabel: updated.address ? `${updated.address.label}, ${updated.address.line1}` : null,
      cityName: updated.address?.city?.name ?? null,
      scheduledAt: updated.scheduledAt.toISOString()
    }
  });
});

// ─── Booking summary (for chat header / tracking page) ────────────────────────
usersRouter.get("/bookings/:bookingId/summary", requireAuth, async (request: AuthenticatedRequest, response) => {
  const { bookingId } = request.params as { bookingId: string };
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
  const { workerId } = request.params as { workerId: string };

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
      skills: profile.skills.map((s: any) => ({
        id: s.id,
        categoryName: s.category.name,
        categorySlug: s.category.slug
      })),
      portfolioPhotos: profile.portfolioPhotos.map((p: any) => ({
        id: p.id,
        url: p.url,
        caption: p.caption ?? null
      })),
      reviews: profile.reviews.map((r: any) => ({
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

// ─── Worker wallet ────────────────────────────────────────────────────────────
usersRouter.get("/worker/wallet", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  const transactions = await prisma.walletTransaction.findMany({
    where: { workerId: workerProfile.id },
    orderBy: { createdAt: "desc" },
    take: 50
  });

  const totalEarnings = transactions
    .filter((t: any) => t.type === "CREDIT" && Number(t.amount) > 0)
    .reduce((sum: number, t: any) => sum + Number(t.amount), 0);

  const pendingPayout = transactions
    .filter((t: any) => t.type === "PAYOUT_PENDING")
    .reduce((sum: number, t: any) => sum + Number(t.amount), 0);

  const lastTx = transactions[0];
  const balance = lastTx ? Number(lastTx.balanceAfter) : 0;

  response.status(200).json({
    balance,
    totalEarnings,
    pendingPayout,
    transactions: transactions.map((t: any) => ({
      id: t.id,
      type: t.type,
      amount: Number(t.amount),
      balanceAfter: Number(t.balanceAfter),
      createdAt: t.createdAt.toISOString(),
      note: t.metadata?.note ?? null
    }))
  });
});

// ─── Worker: request payout ───────────────────────────────────────────────────
usersRouter.post("/worker/wallet/payout", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const { amount, upiId } = request.body as { amount: number; upiId: string };

  if (!amount || typeof amount !== "number" || amount <= 0) {
    response.status(400).json({ message: "amount must be a positive number" });
    return;
  }
  if (!upiId || typeof upiId !== "string" || upiId.trim().length < 3) {
    response.status(400).json({ message: "upiId is required" });
    return;
  }

  // Fetch worker profile + current balance
  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  // Compute current balance from latest transaction
  const lastTx = await prisma.walletTransaction.findFirst({
    where: { workerId: workerProfile.id },
    orderBy: { createdAt: "desc" },
    select: { balanceAfter: true }
  });

  const currentBalance = lastTx ? Number(lastTx.balanceAfter) : 0;

  if (amount > currentBalance) {
    response.status(400).json({ message: "Insufficient wallet balance" });
    return;
  }

  const newBalance = currentBalance - amount;

  // Create a PAYOUT_PENDING transaction
  const tx = await prisma.walletTransaction.create({
    data: {
      userId,
      workerId: workerProfile.id,
      type: "PAYOUT_PENDING",
      amount: -amount,
      balanceAfter: newBalance,
      referenceType: "PAYOUT_REQUEST",
      metadata: {
        upiId: upiId.trim(),
        requestedAt: new Date().toISOString(),
        note: `UPI payout of ₹${amount} to ${upiId.trim()}`
      }
    }
  });

  response.status(201).json({
    success: true,
    transactionId: tx.id,
    amountRequested: amount,
    upiId: upiId.trim(),
    newBalance
  });
});

// ─── Worker: update own profile ───────────────────────────────────────────────
usersRouter.patch("/me/worker/profile", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const { fullName, displayName, bio, experienceYears } = request.body as {
    fullName?: string;
    displayName?: string;
    bio?: string;
    experienceYears?: number;
  };

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  const updated = await prisma.workerProfile.update({
    where: { id: workerProfile.id },
    data: {
      ...(fullName !== undefined ? { fullName } : {}),
      ...(displayName !== undefined ? { displayName } : {}),
      ...(bio !== undefined ? { bio } : {}),
      ...(typeof experienceYears === "number" ? { experienceYears } : {}),
    },
    select: {
      id: true, fullName: true, displayName: true, bio: true,
      experienceYears: true, averageRating: true, completedJobsCount: true
    }
  });

  response.status(200).json({ success: true, profile: updated });
});

// ─── Worker: get own profile for editing ─────────────────────────────────────
usersRouter.get("/me/worker/profile", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: {
      id: true, fullName: true, displayName: true, bio: true,
      experienceYears: true, verificationStatus: true,
      averageRating: true, completedJobsCount: true,
      user: { select: { avatarUrl: true } }
    }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  response.status(200).json({
    id: workerProfile.id,
    fullName: workerProfile.fullName,
    displayName: workerProfile.displayName,
    bio: workerProfile.bio,
    experienceYears: workerProfile.experienceYears,
    verificationStatus: workerProfile.verificationStatus,
    averageRating: Number(workerProfile.averageRating),
    completedJobsCount: workerProfile.completedJobsCount,
    avatarUrl: workerProfile.user.avatarUrl ?? null
  });
});

// ─── Worker: get documents ─────────────────────────────────────────────────────
usersRouter.get("/me/worker/documents", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true, documents: { select: { id: true, type: true, url: true, verifiedAt: true, rejectedAt: true } } }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  response.status(200).json({ documents: workerProfile.documents });
});

// ─── Worker: upload a new document ───────────────────────────────────────────
usersRouter.post("/me/worker/documents", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const { type, url } = request.body as { type?: string; url?: string };
  if (!type || !url) {
    response.status(400).json({ message: "type and url are required" });
    return;
  }

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  const newDoc = await prisma.workerDocument.create({
    data: {
      workerId: workerProfile.id,
      type,
      url,
    }
  });

  response.status(201).json({ document: newDoc });
});

// ─── Worker: decline a job offer ─────────────────────────────────────────────
usersRouter.post("/me/worker/jobs/:offerId/decline", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const { offerId } = request.params as { offerId: string };
  const { reason } = request.body as { reason?: string };

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  const offer = await prisma.dispatchOffer.findFirst({
    where: { id: offerId, workerId: workerProfile.id, status: "pending" }
  });

  if (!offer) {
    response.status(404).json({ message: "Offer not found or already actioned" });
    return;
  }

  await prisma.dispatchOffer.update({
    where: { id: offerId },
    data: {
      status: "declined",
      respondedAt: new Date()
    }
  });

  response.status(200).json({ success: true });
});
