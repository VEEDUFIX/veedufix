# Live Partner Tracking Audit

Audit performed against the existing VeeduFix source before implementation.

## Existing behavior

- The backend already provides an authenticated WebSocket at `/api/tracking/ws`; connection authorization checks that the caller is the booking's customer, assigned Partner, or an Admin.
- The WebSocket accepted `location.update` from any authenticated Partner after connection, without verifying assignment or booking state for that message. It broadcast coordinates but did not persist a latest-location snapshot or enforce update frequency.
- The Partner job execution provider automatically requested location and began publishing when a job page opened. A second `locationBroadcasterProvider` also published every eight seconds during later execution steps, including after arrival. These are competing mechanisms.
- The Partner app already has a `POST /bookings/:bookingId/en-route` client call, but no matching backend route was mounted.
- The job execution arrival endpoint already changes booking state and stores an arrival coordinate. Completion and cancellation use the existing booking lifecycle.
- Customer tracking already renders a Google map and a freshness state, but it has no authenticated initial location snapshot and no road-routing ETA. Its parser substituted the current time when an update timestamp was missing.
- Backend `getTravelTimeMinutes` uses Google Distance Matrix when configured, but falls back to a straight-line estimate. That helper is suitable for matching only; it must not be used to present customer-facing driving ETA.
- Admin has a booking detail page and authorized booking API, but no live-tracking status or location card.
- Redis and realtime publishing are already configured, so short-lived Redis location snapshots can avoid a database migration and long-term storage of precise live coordinates.

## Gaps to address

- Add authenticated en-route, location-update, and tracking-snapshot API behavior with booking/assignment checks, strict coordinate validation, server timestamps, frequency limits, and short retention.
- Reject location publication over the generic WebSocket message path; keep the socket as a read-only authorized event stream.
- Make Partner tracking an explicit foreground-only opt-in for the en-route state and remove duplicate post-arrival broadcasting.
- Seed Customer tracking from an authorized snapshot, reject invalid/missing timestamps, show stale/unavailable states, and expose ETA only when road-routing returns a real result.
- Add an Admin booking-detail view of tracking state and latest data.
- Add focused tests for authorization, lifecycle, validation, rate limits, stale snapshots, and unavailable routing.

## Files expected to change

- Backend: `src/modules/tracking/*`, `src/app.ts`, `src/lib/realtime.ts`, and focused tests; `src/lib/maps.ts` only for a route-only ETA helper.
- Partner: job execution provider/page, arrival step, remove `worker_availability_provider.dart` tracking publisher, and add the iOS foreground-location usage explanation.
- Customer: tracking provider/page.
- Admin: booking detail page.

No database migration is required for the planned Redis TTL snapshot. No database mutation or app build is part of this work.
