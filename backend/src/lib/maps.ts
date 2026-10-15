import { env } from "../config/env.js";
import { redis } from "./redis.js";
import { logger } from "./logger.js";

// ── Types ──────────────────────────────────────────────────────────────────────

interface DistanceMatrixElement {
  status: string;
  duration: { value: number; text: string };
  duration_in_traffic?: { value: number; text: string };
  distance: { value: number; text: string };
}

interface DistanceMatrixResponse {
  status: string;
  rows: Array<{ elements: DistanceMatrixElement[] }>;
}

// ── Haversine fallback ─────────────────────────────────────────────────────────
// Conservative city-speed estimate used only when routing data is unavailable.

export function haversineDistanceKm(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number
): number {
  const R = 6371;
  const dLat = ((destLat - originLat) * Math.PI) / 180;
  const dLng = ((destLng - originLng) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((originLat * Math.PI) / 180) *
      Math.cos((destLat * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

function haversineTravelMinutes(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number
): number {
  const distKm = haversineDistanceKm(originLat, originLng, destLat, destLng);
  // Approximate a dense urban trip, then add time for parking and setup.
  return Math.ceil((distKm / 20) * 60) + 5;
}

// ── Main export ────────────────────────────────────────────────────────────────

/**
 * Returns estimated driving time in minutes between two coordinates.
 * Uses Google Maps Distance Matrix API with live traffic when GOOGLE_MAPS_API_KEY
 * is configured. Falls back to a generic Haversine estimate if the
 * API is unavailable or the key is not set. The fallback is an estimate and
 * does not model local traffic conditions.
 *
 * Results are cached in Redis for 10 minutes to avoid redundant API calls during
 * the dispatch waterfall (multiple candidates, same destination).
 */
export async function getTravelTimeMinutes(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number
): Promise<number> {
  const apiKey = env.GOOGLE_MAPS_API_KEY;

  // Round to 4 decimal places (~11 m precision) for cache key stability
  const cacheKey = `maps:tt:${originLat.toFixed(4)},${originLng.toFixed(4)}->${destLat.toFixed(4)},${destLng.toFixed(4)}`;

  const cached = await redis.get(cacheKey);
  if (cached) {
    return Number(cached);
  }

  if (!apiKey) {
    const minutes = haversineTravelMinutes(originLat, originLng, destLat, destLng);
    logger.debug(
      { originLat, originLng, destLat, destLng, minutes },
      "getTravelTimeMinutes: no API key, using Haversine fallback"
    );
    return minutes;
  }

  try {
    const url =
      `https://maps.googleapis.com/maps/api/distancematrix/json` +
      `?origins=${originLat},${originLng}` +
      `&destinations=${destLat},${destLng}` +
      `&mode=driving` +
      `&departure_time=now` +
      `&traffic_model=best_guess` +
      `&key=${apiKey}`;

    const response = await fetch(url, { signal: AbortSignal.timeout(4000) });
    const data = (await response.json()) as DistanceMatrixResponse;

    const element = data?.rows?.[0]?.elements?.[0];
    if (element?.status === "OK") {
      // Prefer traffic-aware duration when available
      const seconds =
        element.duration_in_traffic?.value ?? element.duration.value;
      const minutes = Math.ceil(seconds / 60);

      // Cache for 10 minutes — traffic conditions don't change much faster
      await redis.set(cacheKey, String(minutes), "EX", 600);

      logger.debug(
        { originLat, originLng, destLat, destLng, minutes },
        "getTravelTimeMinutes: Google Maps result"
      );
      return minutes;
    }

    logger.warn(
      { status: data?.status, element: element?.status },
      "getTravelTimeMinutes: unexpected Google Maps response, falling back"
    );
  } catch (err) {
    logger.warn(
      { err },
      "getTravelTimeMinutes: Google Maps API error, using Haversine fallback"
    );
  }

  return haversineTravelMinutes(originLat, originLng, destLat, destLng);
}

/** Returns only a road-routing ETA. Unlike the matching helper above, this
 * deliberately has no geometric fallback: customer-facing ETAs must not imply
 * driving time when a maps route could not be obtained.
 */
export async function getRoadRouteEtaMinutes(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number
): Promise<number | null> {
  const apiKey = env.GOOGLE_MAPS_API_KEY;
  if (!apiKey) return null;
  const cacheKey = `maps:route-eta:${originLat.toFixed(3)},${originLng.toFixed(3)}->${destLat.toFixed(3)},${destLng.toFixed(3)}`;
  try {
    const cached = await redis.get(cacheKey);
    if (cached) return Number(cached);
  } catch (error) {
    logger.warn({ error }, "Road ETA cache unavailable; requesting a fresh route");
  }
  try {
    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${originLat},${originLng}&destinations=${destLat},${destLng}&mode=driving&departure_time=now&traffic_model=best_guess&key=${apiKey}`;
    const response = await fetch(url, { signal: AbortSignal.timeout(4000) });
    if (!response.ok) return null;
    const data = (await response.json()) as DistanceMatrixResponse;
    const element = data?.rows?.[0]?.elements?.[0];
    if (data.status !== "OK" || element?.status !== "OK") return null;
    const seconds = element.duration_in_traffic?.value ?? element.duration?.value;
    if (!Number.isFinite(seconds) || seconds <= 0) return null;
    const minutes = Math.ceil(seconds / 60);
    try {
      await redis.set(cacheKey, String(minutes), "EX", 60);
    } catch (error) {
      logger.warn({ error }, "Unable to cache road ETA");
    }
    return minutes;
  } catch (error) {
    logger.warn({ error }, "Road ETA unavailable");
    return null;
  }
}
