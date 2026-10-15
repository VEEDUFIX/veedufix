import { BookingStatus } from "@prisma/client";
import { Router } from "express";
import { z } from "zod";
import { getRoadRouteEtaMinutes } from "../../lib/maps.js";
import { prisma } from "../../lib/prisma.js";
import { redis } from "../../lib/redis.js";
import { logger } from "../../lib/logger.js";
import { publishTrackingEvent } from "../../lib/realtime.js";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { recordBookingTimelineEvent } from "../../lib/booking-timeline.js";

export const trackingRouter = Router();

const paramsSchema = z.object({ params: z.object({ bookingId: z.string().min(1).max(128) }) });
export const trackingLocationSchema = z.object({
  params: z.object({ bookingId: z.string().min(1).max(128) }),
  body: z.object({
    lat: z.number().finite().min(-90).max(90),
    lng: z.number().finite().min(-180).max(180),
    heading: z.number().finite().min(0).max(360).optional(),
    capturedAt: z.string().datetime({ offset: true })
  })
});

const LOCATION_TTL_SECONDS = 180;
const MIN_UPDATE_INTERVAL_SECONDS = 5;
const TRACKING_STATUS = BookingStatus.EN_ROUTE;

type TrackingRecord = {
  status: BookingStatus;
  customerId: string;
  workerId: string | null;
  worker: { userId: string | null } | null;
  address: { latitude: unknown; longitude: unknown };
};

async function getBooking(bookingId: string): Promise<TrackingRecord | null> {
  return (await prisma.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      status: true,
      customerId: true,
      workerId: true,
      worker: { select: { userId: true } },
      address: { select: { latitude: true, longitude: true } }
    }
  })) as TrackingRecord | null;
}

function isAuthorized(booking: TrackingRecord, auth: NonNullable<AuthenticatedRequest["auth"]>): boolean {
  return auth.role === "ADMIN" ||
    (auth.role === "CUSTOMER" && booking.customerId === auth.userId) ||
    (auth.role === "WORKER" && booking.worker?.userId === auth.userId);
}

function locationKey(bookingId: string): string {
  return `tracking:location:${bookingId}`;
}

function rateLimitKey(bookingId: string): string {
  return `tracking:location-rate:${bookingId}`;
}

export async function clearBookingTracking(bookingId: string, status?: BookingStatus): Promise<void> {
  try {
    await redis.del(locationKey(bookingId), rateLimitKey(bookingId));
    if (status) await publishTrackingEvent({ bookingId, status });
  } catch (error) {
    logger.warn({ error, bookingId }, "Unable to clear short-lived booking tracking state");
  }
}

export async function beginEnRoute(bookingId: string, userId: string): Promise<BookingStatus> {
  const booking = await getBooking(bookingId);
  if (!booking || booking.worker?.userId !== userId) {
    const error = new Error("You are not assigned to this booking");
    Object.assign(error, { statusCode: booking ? 403 : 404 });
    throw error;
  }
  if (booking.status === TRACKING_STATUS) return booking.status;
  if (booking.status !== BookingStatus.WORKER_ASSIGNED) {
    const error = new Error("Tracking can start only for an assigned booking");
    Object.assign(error, { statusCode: 409 });
    throw error;
  }
  const updated = await prisma.booking.updateMany({
    where: { id: bookingId, workerId: booking.workerId, status: BookingStatus.WORKER_ASSIGNED },
    data: { status: TRACKING_STATUS }
  });
  if (updated.count !== 1) {
    const error = new Error("Booking state changed; refresh and try again");
    Object.assign(error, { statusCode: 409 });
    throw error;
  }
  await redis.del(locationKey(bookingId), rateLimitKey(bookingId));
  await publishTrackingEvent({ bookingId, status: TRACKING_STATUS, actorRole: "WORKER" });
  void recordBookingTimelineEvent({
    bookingId,
    status: TRACKING_STATUS,
    title: "Partner is on the way",
    description: "The assigned Partner started travelling to the service address."
  });
  return TRACKING_STATUS;
}

export async function postLocation(
  bookingId: string,
  userId: string,
  coords: { lat: number; lng: number; heading?: number; capturedAt: string }
): Promise<{ timestamp: string }> {
  const booking = await getBooking(bookingId);
  if (!booking || booking.worker?.userId !== userId) {
    const error = new Error("You are not assigned to this booking");
    Object.assign(error, { statusCode: booking ? 403 : 404 });
    throw error;
  }
  if (booking.status !== TRACKING_STATUS) {
    const error = new Error("Live location is accepted only while the Partner is en route");
    Object.assign(error, { statusCode: 409 });
    throw error;
  }
  const capturedAtMs = Date.parse(coords.capturedAt);
  if (!Number.isFinite(capturedAtMs) || capturedAtMs > Date.now() + 90_000 || Date.now() - capturedAtMs > 90_000) {
    const error = new Error("Location fix is too old or has an invalid device timestamp");
    Object.assign(error, { statusCode: 422 });
    throw error;
  }

  const allowed = await redis.set(rateLimitKey(bookingId), "1", "EX", MIN_UPDATE_INTERVAL_SECONDS, "NX");
  if (allowed !== "OK") {
    const error = new Error("Location update received too soon");
    Object.assign(error, { statusCode: 429 });
    throw error;
  }
  const location = {
    lat: coords.lat,
    lng: coords.lng,
    heading: coords.heading ?? 0,
    timestamp: new Date().toISOString()
  };
  await redis.set(locationKey(bookingId), JSON.stringify(location), "EX", LOCATION_TTL_SECONDS);
  await publishTrackingEvent({ bookingId, ...location, status: TRACKING_STATUS, actorRole: "WORKER" });
  return { timestamp: location.timestamp };
}

export async function getTracking(bookingId: string, userId: string, role: "CUSTOMER" | "WORKER" | "ADMIN") {
  const booking = await getBooking(bookingId);
  if (!booking) return { notFound: true as const };
  if (!isAuthorized(booking, { userId, role, sessionId: "" })) return { forbidden: true as const };
  if (booking.status !== TRACKING_STATUS) {
    return { status: booking.status, active: false, location: null, etaMinutes: null };
  }
  const raw = await redis.get(locationKey(bookingId));
  const location = raw ? JSON.parse(raw) as { lat: number; lng: number; heading: number; timestamp: string } : null;
  const locationAgeMs = location === null ? null : Date.now() - Date.parse(location.timestamp);
  const isFresh = locationAgeMs !== null && locationAgeMs >= 0 && locationAgeMs <= LOCATION_TTL_SECONDS * 1000;
  if (!location || !isFresh) return { status: booking.status, active: true, location: null, etaMinutes: null };
  const destLat = booking.address.latitude == null ? null : Number(booking.address.latitude);
  const destLng = booking.address.longitude == null ? null : Number(booking.address.longitude);
  const etaMinutes = destLat !== null && destLng !== null
    ? await getRoadRouteEtaMinutes(location.lat, location.lng, destLat, destLng)
    : null;
  return { status: booking.status, active: true, location, etaMinutes };
}

function sendError(response: import("express").Response, error: unknown): void {
  const statusCode = Number((error as { statusCode?: unknown })?.statusCode);
  const known = statusCode >= 400 && statusCode < 500;
  response.status(known ? statusCode : 500).json({
    message: known && error instanceof Error ? error.message : "Tracking request failed"
  });
}

trackingRouter.post("/bookings/:bookingId/en-route", requireAuth, requireRole("WORKER"), validate(paramsSchema), async (request, response) => {
  try {
    const auth = (request as AuthenticatedRequest).auth!;
    const bookingId = String(request.params.bookingId);
    const status = await beginEnRoute(bookingId, auth.userId);
    response.setHeader("Cache-Control", "private, no-store");
    response.status(200).json({ bookingId, status });
  } catch (error) { sendError(response, error); }
});

trackingRouter.post("/bookings/:bookingId/tracking/location", requireAuth, requireRole("WORKER"), validate(trackingLocationSchema), async (request, response) => {
  try {
    const auth = (request as AuthenticatedRequest).auth!;
    const result = await postLocation(String(request.params.bookingId), auth.userId, request.body);
    response.setHeader("Cache-Control", "private, no-store");
    response.status(200).json(result);
  } catch (error) { sendError(response, error); }
});

trackingRouter.get("/bookings/:bookingId/tracking", requireAuth, requireRole("CUSTOMER", "WORKER", "ADMIN"), validate(paramsSchema), async (request, response) => {
  try {
    const auth = (request as AuthenticatedRequest).auth!;
    const result = await getTracking(String(request.params.bookingId), auth.userId, auth.role);
    response.setHeader("Cache-Control", "private, no-store");
    if ("notFound" in result) { response.status(404).json({ message: "Booking not found" }); return; }
    if ("forbidden" in result) { response.status(403).json({ message: "You are not authorized to view this booking" }); return; }
    response.status(200).json(result);
  } catch (error) { sendError(response, error); }
});
