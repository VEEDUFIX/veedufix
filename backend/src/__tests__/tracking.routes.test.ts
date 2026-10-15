import { beforeEach, describe, expect, it, vi } from "vitest";
import { BookingStatus } from "@prisma/client";

vi.mock("../lib/prisma.js", () => ({
  prisma: { booking: { findUnique: vi.fn(), updateMany: vi.fn() } }
}));
vi.mock("../lib/redis.js", () => ({
  redis: { get: vi.fn(), set: vi.fn(), del: vi.fn() }
}));
vi.mock("../lib/realtime.js", () => ({ publishTrackingEvent: vi.fn() }));
vi.mock("../lib/maps.js", () => ({ getRoadRouteEtaMinutes: vi.fn() }));
vi.mock("../lib/logger.js", () => ({ logger: { warn: vi.fn() } }));
vi.mock("../lib/booking-timeline.js", () => ({ recordBookingTimelineEvent: vi.fn() }));

import { prisma } from "../lib/prisma.js";
import { redis } from "../lib/redis.js";
import { getRoadRouteEtaMinutes } from "../lib/maps.js";
import {
  beginEnRoute,
  getTracking,
  postLocation,
  trackingLocationSchema
} from "../modules/tracking/tracking.routes.js";

const assignedBooking = {
  id: "booking-1",
  status: BookingStatus.WORKER_ASSIGNED,
  customerId: "customer-1",
  workerId: "worker-profile-1",
  worker: { userId: "worker-user-1" },
  address: { latitude: 13, longitude: 80 }
};
const freshFix = { lat: 13, lng: 80, capturedAt: new Date().toISOString() };

describe("booking live tracking", () => {
  it("uses the generated Prisma EN_ROUTE booking status", () => {
    expect(BookingStatus.EN_ROUTE).toBe("EN_ROUTE");
  });

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(assignedBooking as never);
    vi.mocked(prisma.booking.updateMany).mockResolvedValue({ count: 1 } as never);
    vi.mocked(redis.set).mockResolvedValue("OK" as never);
    vi.mocked(redis.del).mockResolvedValue(1 as never);
    vi.mocked(redis.get).mockResolvedValue(null);
    vi.mocked(getRoadRouteEtaMinutes).mockResolvedValue(null);
  });

  it("allows only the assigned Partner to start the trip", async () => {
    await expect(beginEnRoute("booking-1", "worker-user-1")).resolves.toBe(BookingStatus.EN_ROUTE);
    await expect(beginEnRoute("booking-1", "another-worker")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("requires an assigned booking before accepting location updates", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.PENDING
    } as never);
    await expect(postLocation("booking-1", "worker-user-1", freshFix))
      .rejects.toMatchObject({ statusCode: 409 });
    expect(redis.set).not.toHaveBeenCalled();
  });

  it("validates geographic coordinate bounds in request payloads", () => {
    expect(trackingLocationSchema.safeParse({
      params: { bookingId: "booking-1" },
      body: { lat: 91, lng: 80 }
    }).success).toBe(false);
    expect(trackingLocationSchema.safeParse({
      params: { bookingId: "booking-1" },
      body: { lat: 13, lng: 80, heading: 361 }
    }).success).toBe(false);
  });

  it("stores only server-timestamped, short-lived updates and publishes them", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.EN_ROUTE
    } as never);
    const result = await postLocation("booking-1", "worker-user-1", { ...freshFix, heading: 20 });
    expect(Date.parse(result.timestamp)).not.toBeNaN();
    expect(redis.set).toHaveBeenCalledWith(
      "tracking:location:booking-1",
      expect.stringContaining('"lat":13'),
      "EX",
      180
    );
  });

  it("rejects updates that exceed the minimum interval", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.EN_ROUTE
    } as never);
    vi.mocked(redis.set).mockResolvedValueOnce(null as never);
    await expect(postLocation("booking-1", "worker-user-1", freshFix))
      .rejects.toMatchObject({ statusCode: 429 });
  });

  it("returns a snapshot only to the booking parties and only for active travel", async () => {
    const active = { ...assignedBooking, status: BookingStatus.EN_ROUTE };
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce(active as never);
    await expect(getTracking("booking-1", "someone-else", "CUSTOMER"))
      .resolves.toMatchObject({ forbidden: true });
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce(active as never);
    vi.mocked(redis.get).mockResolvedValueOnce(JSON.stringify({
      lat: 12.9716,
      lng: 77.5946,
      heading: 45,
      timestamp: new Date().toISOString()
    }));
    await expect(getTracking("booking-1", "customer-1", "CUSTOMER"))
      .resolves.toMatchObject({
        status: BookingStatus.EN_ROUTE,
        active: true,
        location: { lat: 12.9716, lng: 77.5946, heading: 45 }
      });
  });

  it("denies an unassigned Partner and allows Admin access to an active booking", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.EN_ROUTE
    } as never);
    await expect(getTracking("booking-1", "another-worker", "WORKER"))
      .resolves.toMatchObject({ forbidden: true });

    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.EN_ROUTE
    } as never);
    await expect(getTracking("booking-1", "admin-user", "ADMIN"))
      .resolves.toMatchObject({ status: BookingStatus.EN_ROUTE, active: true, location: null });
  });

  it("hides expired snapshots and never returns locations after tracking ends", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.EN_ROUTE
    } as never);
    vi.mocked(redis.get).mockResolvedValueOnce(JSON.stringify({
      lat: 13,
      lng: 80,
      heading: 0,
      timestamp: new Date(Date.now() - 181_000).toISOString()
    }));
    await expect(getTracking("booking-1", "customer-1", "CUSTOMER"))
      .resolves.toMatchObject({ active: true, location: null, etaMinutes: null });
    expect(getRoadRouteEtaMinutes).not.toHaveBeenCalled();

    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.IN_PROGRESS
    } as never);
    await expect(getTracking("booking-1", "customer-1", "CUSTOMER"))
      .resolves.toMatchObject({ active: false, location: null, etaMinutes: null });
    expect(redis.get).toHaveBeenCalledTimes(1);
  });

  it("rejects future-dated cache entries", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.EN_ROUTE
    } as never);
    vi.mocked(redis.get).mockResolvedValue(JSON.stringify({
      lat: 13,
      lng: 80,
      heading: 0,
      timestamp: "2099-01-01T00:00:00.000Z"
    }));
    await expect(getTracking("booking-1", "customer-1", "CUSTOMER"))
      .resolves.toMatchObject({ active: true, location: null, etaMinutes: null });
    expect(getRoadRouteEtaMinutes).not.toHaveBeenCalled();
  });

  it("exposes ETA only when valid road-routing data is available", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.EN_ROUTE
    } as never);
    vi.mocked(redis.get).mockResolvedValue(JSON.stringify({
      lat: 13,
      lng: 80,
      heading: 0,
      timestamp: new Date().toISOString()
    }));
    vi.mocked(getRoadRouteEtaMinutes).mockResolvedValueOnce(9);
    await expect(getTracking("booking-1", "customer-1", "CUSTOMER"))
      .resolves.toMatchObject({ active: true, etaMinutes: 9 });
  });

  it("does not provide geometric ETA when road routing is unavailable", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValueOnce({
      ...assignedBooking,
      status: BookingStatus.EN_ROUTE
    } as never);
    vi.mocked(redis.get).mockResolvedValueOnce(JSON.stringify({
      lat: 13,
      lng: 80,
      heading: 0,
      timestamp: new Date().toISOString()
    }));
    vi.mocked(getRoadRouteEtaMinutes).mockResolvedValueOnce(null);
    await expect(getTracking("booking-1", "customer-1", "CUSTOMER"))
      .resolves.toMatchObject({ active: true, etaMinutes: null });
  });
});
