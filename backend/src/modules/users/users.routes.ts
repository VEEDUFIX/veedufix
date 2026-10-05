import { Router } from "express";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { getBookingTimelineEvents } from "../../lib/booking-timeline.js";
import { serializeWorkerProfile } from "../worker-onboarding/worker-onboarding.service.js";
import { requestWorkerPayout } from "../wallet/wallet.service.js";
import { generateSignedUrl, getCloudinaryFormatFromUrl } from "../../lib/cloudinary.js";
import { getCustomerScheduleSlots } from "../availability/availability.service.js";
import { createUserDataExport } from "./data-export.service.js";

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
usersRouter.get("/me/notification-preferences", requireAuth, async (request: AuthenticatedRequest, response) => {
  const user = await prisma.user.findUnique({
    where: { id: request.auth!.userId },
    select: { marketingNotificationsEnabled: true }
  });
  if (!user) {
    response.status(404).json({ message: "User not found" });
    return;
  }
  response.setHeader("Cache-Control", "private, no-store");
  response.status(200).json({ marketingNotificationsEnabled: user.marketingNotificationsEnabled });
});

usersRouter.get("/me/data-export", requireAuth, async (request: AuthenticatedRequest, response) => {
  const exported = await createUserDataExport(request.auth!.userId);
  if (!exported) {
    response.status(404).json({ message: "User not found" });
    return;
  }
  response.setHeader("Cache-Control", "private, no-store");
  response.setHeader("Content-Disposition", 'attachment; filename="veedufix-account-data.json"');
  response.status(200).json(exported);
});

usersRouter.patch("/me/notification-preferences", requireAuth, async (request: AuthenticatedRequest, response) => {
  const enabled = request.body?.marketingNotificationsEnabled;
  if (typeof enabled !== "boolean") {
    response.status(400).json({ message: "marketingNotificationsEnabled must be a boolean" });
    return;
  }
  const user = await prisma.user.update({
    where: { id: request.auth!.userId },
    data: { marketingNotificationsEnabled: enabled },
    select: { marketingNotificationsEnabled: true }
  });
  response.setHeader("Cache-Control", "private, no-store");
  response.status(200).json({ marketingNotificationsEnabled: user.marketingNotificationsEnabled });
});

usersRouter.get("/me", requireAuth, async (request: AuthenticatedRequest, response) => {
  const user = await prisma.user.findUnique({
    where: { id: request.auth!.userId },
    include: {
      city: true,
      workerProfile: {
        include: {
          skills: { include: { category: true } },
          availability: true,
        },
      },
      addresses: true
    }
  });

  if (!user) {
    response.status(404).json({ message: "User not found" });
    return;
  }

  const safeUser = { ...user };
  delete safeUser.passwordHash;
  response.setHeader("Cache-Control", "private, no-store");
  response.status(200).json({
    user: {
      ...safeUser,
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
    statusFilter = [
      "PENDING",
      "ACCEPTED",
      "WORKER_ASSIGNED",
      "EN_ROUTE",
      "ARRIVED",
      "IN_PROGRESS",
      "DISPATCH_FAILED"
    ];
  }

  const bookings = await prisma.booking.findMany({
    where: {
      customerId: userId,
      status: { in: statusFilter }
    },
    orderBy: { scheduledAt: tab === "upcoming" ? "asc" : "desc" },
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
usersRouter.get("/me/worker/jobs", requireAuth, requireRole("WORKER"), async (request: AuthenticatedRequest, response) => {
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
        select: {
          label: true,
          line1: true,
          pincode: true,
          latitude: true,
          longitude: true,
          city: { select: { name: true } }
        },
      },
      sparePartRequest: true,
      jobExecution: {
        select: {
          completedAt: true,
          beforePhotos: true,
          afterPhotos: true,
        },
      },
      refunds: {
        orderBy: { createdAt: "desc" },
        select: {
          id: true,
          amount: true,
          gatewayAmount: true,
          walletAmount: true,
          status: true,
          createdAt: true,
          updatedAt: true,
          walletCreditedAt: true
        }
      }
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
      bookingType: booking.bookingType,
      scheduledAt: booking.scheduledAt.toISOString(),
      addressId: booking.addressId,
      addressLine1: booking.address?.line1 ?? null,
      addressPincode: booking.address?.pincode ?? null,
      addressLatitude: booking.address?.latitude != null ? Number(booking.address.latitude) : null,
      addressLongitude: booking.address?.longitude != null ? Number(booking.address.longitude) : null,
      cityName: booking.address?.city?.name ?? null,
      totalAmount: Number(booking.totalAmount),
      serviceName: booking.services[0]?.service?.name ?? booking.services[0]?.serviceSubcategory?.name ?? "Service",
      serviceIcon: booking.services[0]?.service?.iconUrl ?? null,
      serviceSlug: booking.services[0]?.service?.slug ?? null,
      serviceIds: booking.services.map((item: { serviceId: string | null }) => item.serviceId),
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
      // Dispute window — completedAt from jobExecution lets the app enforce 48h limit
      completedAt: booking.jobExecution?.completedAt?.toISOString() ?? null,
      beforePhotoUrls: booking.jobExecution?.beforePhotos ?? [],
      afterPhotoUrls: booking.jobExecution?.afterPhotos ?? [],
      refunds: booking.refunds.map((refund: {
        id: string;
        amount: unknown;
        gatewayAmount: unknown;
        walletAmount: unknown;
        status: string;
        createdAt: Date;
        updatedAt: Date;
        walletCreditedAt: Date | null;
      }) => ({
        id: refund.id,
        amount: Number(refund.amount),
        gatewayAmount: refund.gatewayAmount == null ? null : Number(refund.gatewayAmount),
        walletAmount: Number(refund.walletAmount ?? 0),
        status: refund.status,
        createdAt: refund.createdAt.toISOString(),
        updatedAt: refund.updatedAt.toISOString(),
        walletCreditedAt: refund.walletCreditedAt?.toISOString() ?? null
      })),
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

usersRouter.get("/bookings/:bookingId/reschedule-slots", requireAuth, async (request: AuthenticatedRequest, response) => {
  const booking = await prisma.booking.findUnique({
    where: { id: String(request.params.bookingId) },
    select: {
      id: true,
      customerId: true,
      status: true,
      workerId: true,
      addressId: true,
      services: { select: { serviceId: true } }
    }
  });
  if (!booking) {
    response.status(404).json({ message: "Booking not found" });
    return;
  }
  if (booking.customerId !== request.auth!.userId) {
    response.status(403).json({ message: "Forbidden" });
    return;
  }
  if (booking.status !== "PENDING" || booking.workerId || booking.services.length === 0 || booking.services.some((item: { serviceId: string | null }) => !item.serviceId)) {
    response.status(409).json({ message: "This booking can no longer be rescheduled" });
    return;
  }
  const startDate = typeof request.query.startDate === "string" ? request.query.startDate : new Date().toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate)) {
    response.status(400).json({ message: "startDate must use YYYY-MM-DD format" });
    return;
  }
  const addressId = typeof request.query.addressId === "string" ? request.query.addressId : booking.addressId;
  const days = Math.min(7, Math.max(1, Number(request.query.days) || 7));
  const slots = await getCustomerScheduleSlots({
    userId: request.auth!.userId,
    addressId,
    serviceIds: booking.services.map((item: { serviceId: string | null }) => item.serviceId).filter((id: string | null): id is string => Boolean(id)),
    startDate,
    days
  });
  response.status(200).json({ slots });
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
      bookingType: true,
      services: { select: { serviceId: true } },
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
  let slotAddressId = booking.addressId;
  let persistSelectedAddress: (() => Promise<{ id: string }>) | null = null;
  if (addressId) {
    const savedAddress = await prisma.savedAddress.findFirst({
      where: { id: addressId, userId }
    });
    if (!savedAddress) {
      response.status(404).json({ message: "Address not found" });
      return;
    }
    let city = await prisma.city.findFirst({
      where: {
        isActive: true,
        name: { equals: savedAddress.city.trim(), mode: "insensitive" }
      },
      select: { id: true }
    });
    if (!city) {
      const area = await prisma.serviceArea.findFirst({
        where: {
          isActive: true,
          OR: [
            { pincode: savedAddress.pincode },
            {
              pincodeRangeStart: { lte: savedAddress.pincode },
              pincodeRangeEnd: { gte: savedAddress.pincode }
            }
          ]
        },
        select: { cityId: true }
      });
      if (area) city = { id: area.cityId };
    }
    if (!city) {
      response.status(400).json({ message: "This address is outside the service area" });
      return;
    }
    nextCityId = city.id;
    slotAddressId = addressId;
    const existingAddress = await prisma.address.findFirst({
      where: {
        userId,
        cityId: city.id,
        label: savedAddress.label,
        line1: savedAddress.addressLine1,
        pincode: savedAddress.pincode
      },
      select: { id: true }
    });
    if (existingAddress) {
      nextAddressId = existingAddress.id;
    } else {
      persistSelectedAddress = () => prisma.address.create({
        data: {
          userId,
          cityId: city.id,
          label: savedAddress.label,
          line1: savedAddress.addressLine1,
          line2: savedAddress.addressLine2,
          landmark: savedAddress.landmark,
          pincode: savedAddress.pincode,
          latitude: savedAddress.lat,
          longitude: savedAddress.lng,
          isDefault: savedAddress.isDefault
        },
        select: { id: true }
      });
    }
  }

  let nextScheduledAt = booking.scheduledAt;
  let nextBookingType = booking.bookingType;
  if (scheduledAt) {
    const parsed = new Date(scheduledAt);
    if (Number.isNaN(parsed.getTime())) {
      response.status(400).json({ message: "scheduledAt is invalid" });
      return;
    }
    if (parsed.getTime() <= Date.now()) {
      response.status(400).json({ message: "Choose a future appointment time" });
      return;
    }
    if (booking.services.some((item: { serviceId: string | null }) => !item.serviceId)) {
      response.status(409).json({ message: "This booking cannot be rescheduled online. Contact support for help." });
      return;
    }
    const slots = await getCustomerScheduleSlots({
      userId,
      addressId: slotAddressId,
      serviceIds: booking.services.map((item: { serviceId: string | null }) => item.serviceId).filter((id: string | null): id is string => Boolean(id)),
      startDate: parsed.toISOString().slice(0, 10),
      days: 1
    });
    if (!slots.some((slot) => new Date(slot.scheduledFor).getTime() === parsed.getTime())) {
      response.status(409).json({ message: "That appointment slot is no longer available. Choose another available time." });
      return;
    }
    nextScheduledAt = parsed;
    nextBookingType = "scheduled";
  }

  if (persistSelectedAddress) {
    nextAddressId = (await persistSelectedAddress()).id;
  }

  const updated = await prisma.$transaction(async (tx) => {
    const changed = await tx.booking.updateMany({
      where: {
        id: booking.id,
        customerId: userId,
        status: "PENDING",
        workerId: null,
        dispatchOffers: { none: { status: "pending" } }
      },
      data: {
        addressId: nextAddressId,
        cityId: nextCityId,
        ...(scheduledAt ? {
          scheduledAt: nextScheduledAt,
          scheduledFor: nextScheduledAt,
          bookingType: nextBookingType
        } : {})
      }
    });
    if (changed.count !== 1) {
      response.status(409).json({ message: "Booking is no longer editable. Refresh and try again." });
      return null;
    }
    if (scheduledAt) {
      await tx.bookingTimelineEvent.create({
        data: {
          bookingId: booking.id,
          status: "PENDING",
          title: "Appointment rescheduled",
          description: `New appointment time: ${nextScheduledAt.toISOString()}`
        }
      });
    }
    const result = await tx.booking.findUnique({
      where: { id: booking.id },
      include: { address: { select: { label: true, line1: true, city: { select: { name: true } } } } }
    });
    if (!result) throw new Error("Updated booking could not be reloaded");
    return result;
  });
  if (!updated) return;

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
usersRouter.get("/workers/:workerId/profile", requireAuth, async (request, response) => {
  const { workerId } = request.params as { workerId: string };

  const profile = await prisma.workerProfile.findUnique({
    where: { id: workerId },
    include: {
      user: { select: { id: true, name: true, avatarUrl: true } },
      skills: {
        include: { category: { select: { name: true, slug: true } } },
        take: 10
      },
      portfolioPhotos: { orderBy: { createdAt: "desc" as const }, take: 12 },
      reviews: {
        where: { moderationStatus: "published" },
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
        workerResponse: r.workerResponse ?? null,
        workerResponseAt: r.workerResponseAt?.toISOString() ?? null,
        customerName: r.reviewer?.name ?? "Customer",
        customerAvatarUrl: r.reviewer?.avatarUrl ?? null,
        createdAt: r.createdAt.toISOString()
      }))
    }
  });
});

// ─── Worker wallet ────────────────────────────────────────────────────────────
usersRouter.get("/worker/wallet", requireAuth, requireRole("WORKER"), async (request: AuthenticatedRequest, response) => {
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
  const platformConfig = await prisma.platformConfig.findUnique({
    where: { key: "primary" },
    select: { minimumWorkerPayout: true, payoutsPaused: true, payoutPauseReason: true }
  });

  response.status(200).json({
    balance,
    totalEarnings,
    pendingPayout,
    minimumPayout: Number(platformConfig?.minimumWorkerPayout ?? 100),
    payoutsPaused: platformConfig?.payoutsPaused ?? false,
    payoutPauseReason: platformConfig?.payoutPauseReason ?? null,
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
usersRouter.post("/worker/wallet/payout", requireAuth, requireRole("WORKER"), async (request: AuthenticatedRequest, response) => {
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

  const payout = await requestWorkerPayout({
    userId,
    amount,
    upiId
  });

    response.status(201).json({
      success: true,
      transactionId: payout.transaction.id,
      amountRequested: amount,
      newBalance: payout.newBalance
    });
  return;

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
usersRouter.patch("/me/worker/profile", requireAuth, requireRole("WORKER"), async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const body = request.body && typeof request.body === "object" && !Array.isArray(request.body)
    ? request.body as Record<string, unknown>
    : null;
  if (!body) {
    response.status(400).json({ message: "A profile update object is required" });
    return;
  }
  const { fullName, displayName, bio, experienceYears } = body;

  if (
    (fullName !== undefined && (typeof fullName !== "string" || fullName.trim().length < 2 || fullName.trim().length > 120)) ||
    (displayName !== undefined && (typeof displayName !== "string" || displayName.trim().length > 80)) ||
    (bio !== undefined && bio !== null && (typeof bio !== "string" || bio.length > 1000)) ||
    (experienceYears !== undefined && (typeof experienceYears !== "number" || !Number.isInteger(experienceYears) || experienceYears < 0 || experienceYears > 60))
  ) {
    response.status(400).json({ message: "One or more profile fields are invalid" });
    return;
  }

  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true, fullName: true, verificationStatus: true }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  if (
    workerProfile.verificationStatus === "VERIFIED" &&
    typeof fullName === "string" &&
    fullName.trim() !== workerProfile.fullName
  ) {
    response.status(409).json({
      message: "Your verified name cannot be changed here. Contact support to request an identity update.",
      code: "VERIFIED_IDENTITY_CHANGE_REQUIRES_REVIEW"
    });
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
usersRouter.get("/me/worker/documents", requireAuth, requireRole("WORKER"), async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId },
    select: { id: true, documents: { select: { id: true, type: true, url: true, publicId: true, verifiedAt: true, rejectedAt: true } } }
  });

  if (!workerProfile) {
    response.status(404).json({ message: "Worker profile not found" });
    return;
  }

  response.setHeader("Cache-Control", "private, no-store");
  response.status(200).json({ documents: workerProfile.documents.map((document: {
    id: string;
    type: string;
    url: string;
    publicId: string | null;
    verifiedAt: Date | null;
    rejectedAt: Date | null;
  }) => ({
    id: document.id,
    type: document.type,
    url: document.publicId && getCloudinaryFormatFromUrl(document.url)
      ? generateSignedUrl(document.publicId, getCloudinaryFormatFromUrl(document.url)!)
      : null,
    verifiedAt: document.verifiedAt,
    rejectedAt: document.rejectedAt
  })) });
});

// ─── Worker: upload a new document ───────────────────────────────────────────
// ─── Worker: decline a job offer ─────────────────────────────────────────────
usersRouter.post("/me/worker/jobs/:offerId/decline", requireAuth, requireRole("WORKER"), async (request: AuthenticatedRequest, response) => {
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

  const declined = await prisma.dispatchOffer.updateMany({
    where: { id: offerId, workerId: workerProfile.id, status: "pending" },
    data: {
      status: "declined",
      respondedAt: new Date()
    }
  });

  if (declined.count !== 1) {
    response.status(409).json({ message: "Offer is no longer available to decline" });
    return;
  }

  response.status(200).json({ success: true });
});
