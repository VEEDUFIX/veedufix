# VeeduFix advanced feature audit

Audit date: 2026-10-09. This audit covers the six requested advanced features across Customer, Partner, Admin, backend/API, database, and existing tests. Repository instructions and existing launch/feature audits were read first. No application code was changed.

## Summary

| Feature | Customer | Partner | Admin | Backend | Overall status | Next action |
|---|---|---|---|---|---|---|
| Photo-assisted booking | Partially implemented | Partially implemented | Missing for customer problem photos | Partially implemented | Partially implemented | Add customer pre-booking upload/preview and booking association; expose authorized media to assigned Partner and Admin. |
| Live Partner tracking and ETA | Partially implemented | Partially implemented | Partially implemented | Partially implemented | Partially implemented | Add ETA, resilient reconnection/background behavior, and enforce active-booking/location lifecycle server-side; verify on devices. |
| Recurring home maintenance | Missing | Missing | Missing | Missing | Missing | Define recurrence, billing, availability and assignment rules, then build the full recurring-booking lifecycle. |
| Digital quotations and customer approval | Partially implemented | Partially implemented | Implemented — unverified | Partially implemented | Partially implemented | Fix customer response endpoint wiring and enforce approved quote amounts in job/payment flow; add lifecycle and concurrency tests. |
| One-tap rebooking | Partially implemented | Missing | Missing | Partially implemented | Partially implemented | Replace navigation-only shortcut with a fresh quote/rebook flow that carries eligible choices for customer review and server validation. |
| Service guarantee and issue resolution | Partially implemented | Missing as a warranty claim flow | Partially implemented | Partially implemented | Partially implemented | Tie configured warranty terms to an authorized, time-bounded claim with photo evidence, status, decision and audit. |

## 1. Photo-assisted booking

**Overall: Partially implemented.** Partner work-progress photos and booking chat attachments exist; customer problem photos are not part of pre-booking or checkout.

- **Customer app — Partially implemented:** `apps/customer_app/lib/features/chat/presentation/pages/chat_page.dart` and `chat_providers.dart` let a customer attach an image to an existing booking chat through `/upload/chat-attachment`. This occurs after a booking/chat exists; no photo picker, preview/replace/remove flow, or upload attached to service selection/checkout was found. Chat attachments are not equivalent to pre-booking problem photos.
- **Partner app — Partially implemented:** `apps/worker_app/lib/features/worker/presentation/providers/job_execution_provider.dart` (`pickAndUploadPhotos`, `_uploadPhotos`) and `widgets/job_photo_step.dart` support before/after job photos, including selection, drafts, retry/offline queue behavior and a five-photo-per-step limit. This is Partner-authored job evidence, not a customer problem-photo intake/review flow.
- **Admin panel — Missing for this feature:** `apps/admin_web/lib/features/ops/presentation/pages/dispute_detail_page.dart` can show Partner before/after evidence for a dispute. No Admin surface was found to review customer problem photos attached before booking because that data flow/model is absent.
- **Backend/API/database — Partially implemented:** `backend/src/modules/upload/upload.routes.ts` exposes worker-only `/job-photo` and `/job-photo/confirm`; `upload.service.ts` checks assigned Partner, records timeline/notification/realtime events and uses Cloudinary. `chat-attachment` authorizes either booking participant. Multer allows JPEG/PNG up to 5 MB. Prisma `JobExecution.beforePhotos/afterPhotos` stores Partner work photos; chat message attachments are JSON. No customer problem-photo association to a service/booking before checkout was found. No dedicated storage permissions/retention model for customer intake photos was found.
- **Tests and result:** Existing `backend/src/__tests__/upload.test.ts` exercises worker assignment authorization, upload/recording and signed-upload confirmation. It passed as part of the targeted run below. It does not test customer pre-booking photos, chat access on client devices, photo replacement/removal or end-to-end booking visibility.
- **Missing behavior / next action:** Add upload draft lifecycle to service detail/checkout; persist photo metadata against the booking request; enforce file count/size/type/content and customer ownership; expose photos only to the booking customer, assigned Partner and authorized operations staff; test upload failure, retry, offline, removal and access denial. Confirm image picker permissions and network behavior on real devices.

## 2. Live Partner tracking and ETA

**Overall: Partially implemented.** There is a genuine live coordinate stream over WebSocket while the Partner is travelling, not merely a static map. ETA and resilient/background tracking were not found.

- **Customer app — Partially implemented:** `apps/customer_app/lib/features/tracking/presentation/providers/tracking_providers.dart` subscribes by booking ID and parses streamed `lat/lng`; `pages/live_tracking_page.dart` shows the Partner on Google Maps, shows location freshness and stops display for completed/cancelled bookings. No ETA calculation or ETA update behavior was found.
- **Partner app — Partially implemented:** `apps/worker_app/lib/features/worker/presentation/providers/job_execution_provider.dart` (`_startLiveTracking`) requests location permission, streams Geolocator positions and sends them over the booking tracking channel while the relevant job step is active. `markArrived()` calls `_cancelTracking()`; disposal/step changes also stop the stream. No background-location service or app-lifecycle recovery was found.
- **Admin panel — Partially implemented:** `apps/admin_web/lib/features/ops/presentation/pages/god_mode_map_page.dart` refreshes every 30 seconds and plots `liveJobs`. Backend `ops.service.ts` maps `JobExecution.workerLat/workerLng`; those DB fields are updated by the arrival API. This is an operations map of stored coordinates/polled job data, not a live feed of current Partner positions.
- **Backend/API/database — Partially implemented:** `backend/src/lib/realtime.ts` authenticates the WebSocket token and checks that the user is the booking customer, assigned Partner, or Admin before subscription. Only a WORKER-role socket can send location updates. Events are published over Redis. `JobExecution.workerLat/workerLng` persist coordinates via arrival handling; the WebSocket stream itself is not persisted. No ETA service/field was found. The shared `packages/marketplace_shared/lib/core/network/realtime_service.dart` has no reconnect logic (`onDone`/`onError` are no-ops); no background tracking integration was found. Connection authorization checks booking membership but does not itself enforce booking status; worker client lifecycle is the main sender constraint.
- **Tests and result:** No focused tracking/realtime test file was found in the inspected test inventory. None of the 19 executed tests covered tracking. No device/background/network-recovery run was performed.
- **Missing behavior / next action:** Define ETA computation and update cadence; add reconnect/resubscribe and stale-location behavior; handle app backgrounding with platform-appropriate permission/foreground-service policy; stop updates server-side outside eligible job states; verify subscriber authorization, retention/privacy and stop conditions on Android/iOS with network interruptions.

## 3. Recurring home maintenance

**Overall: Missing.**

- **Customer app — Missing:** No recurring schedule creation, frequency selection, upcoming series, edit/pause/cancel, or recurring appointment management was found. A profile tile in `apps/customer_app/lib/features/profile/presentation/pages/profile_page.dart` says “Repeat your most used bookings” but routes to `/favorites`; it is saved-service marketing copy, not a recurring booking scheduler.
- **Partner app — Missing:** No recurring assignment/series or repeat-service schedule interface was found.
- **Admin panel — Missing:** No recurring booking or recurrence policy controls were found.
- **Backend/API/database — Missing:** No recurring booking/series model, recurrence API, generation scheduler, recurrence idempotency, per-occurrence price/availability resolution or assignment logic was found in `backend/prisma/schema.prisma` and inspected backend modules. Existing scheduled booking and lifecycle-notification schedulers do not create a recurring series.
- **Tests and result:** No recurrence-specific tests were found. None were run.
- **Missing behavior / next action:** Define supported frequencies, customer consent and edit/cancel semantics, price/availability changes, Partner assignment per occurrence, payment timing, reminders, missed-service handling and idempotency before implementation. Then add model/API/UI/Admin controls and tests across the complete recurring lifecycle.

## 4. Digital quotations and customer approval

**Overall: Partially implemented.** The quote request, Partner/Admin submission, display and server-side respond service exist, but the Customer response UI is wired to endpoints the backend does not expose; audit/version/expiry and charge enforcement are incomplete.

- **Customer app — Partially implemented:** `apps/customer_app/lib/features/booking/presentation/pages/custom_quote_page.dart` requests a quote at `/bookings/:id/custom-quote/request`; booking detail displays quote information and `_CustomQuoteBannerState._respond()` posts to `/bookings/:id/accept-quote` or `/bookings/:id/reject-quote`. Those paths do not exist in the inspected backend routes. The backend route is `/bookings/:bookingId/custom-quote/respond` with body `{accept: boolean}`. The page also displays `REJECTED`, while the backend service records `DECLINED`. Thus the user-visible approval/rejection actions are not confirmed functional and the rejection label will not match the backend status.
- **Partner app — Partially implemented:** `apps/worker_app/lib/features/worker/presentation/pages/generate_quote_page.dart` lets the assigned Partner create line items and submit the amount/notes via `worker_job_api.dart`. The UI maps each item to `qty: 1`; it has no explicit quantity field or labour/material/fee categories. It describes customer approval before proceeding, but the backend does not enforce that rule in job execution.
- **Admin panel — Implemented — unverified:** `apps/admin_web/lib/features/admin/presentation/pages/booking_detail_page.dart` displays quote state and provides a custom quote submission card; `booking_management_page.dart` can filter bookings with quote requests. No focused Admin quote test was found; no Admin test was run.
- **Backend/API/database — Partially implemented:** `backend/src/modules/bookings/custom-quote.routes.ts` defines request, submit, respond and get routes. `custom-quote.service.ts` checks customer ownership, assigned Partner identity and submitted state. `Booking` stores `customQuoteAmount`, `customQuoteItemized`, `customQuoteNotes`, and a free-form status string. The service uses read-then-update rather than an atomic state claim; there is no quote revision/history, dedicated submitted/accepted timestamp, or expiry. No custom quote amount integration was found in payment total calculation, and job execution has no approval gate. This means the code does not establish that additional quoted work cannot proceed/be charged before approval, nor how an accepted additional amount is collected.
- **Tests and result:** `backend/src/__tests__/custom-quote.service.test.ts` only tests read access by owning customer/assigned Partner and rejection of unrelated user. It passed in the targeted run. It does not test request/submit/respond, endpoint wiring, status mismatch, concurrent responses, quote expiry or payment enforcement.
- **Missing behavior / next action:** Align Flutter response URL/body and `DECLINED`/`REJECTED` status. Add atomic transitions, explicit revisions and expiry policy, quote audit events and server-side amount validation. Define how accepted quote amounts are paid and block execution/charging until approval as appropriate. Add tests for assigned-Person permissions, edits/revisions, concurrent approve/reject, expired quote, payment mismatch and attempting to proceed while unapproved.

## 5. One-tap rebooking

**Overall: Partially implemented.** Booking-history/detail surfaces provide a Book Again shortcut, but it navigates to a service/search screen; it does not create a rebook draft with prior selections.

- **Customer app — Partially implemented:** `apps/customer_app/lib/features/booking/presentation/pages/booking_detail_page.dart` and `bookings_page.dart` expose Book Again. `_openRebookBooking()` navigates to `/service?id=<serviceSlug>` or `/search?q=<serviceName>`. It does not pass the old variant/add-ons/quantity, address or preferred time into a rebook flow. The customer must use the ordinary service selection and checkout.
- **Partner app — Missing as a rebooking feature:** No Partner rebook workflow was found; the Partner receives a normal new job only after a new booking is created.
- **Admin panel — Missing as a rebooking feature:** No Admin rebook action or rebook-specific controls were found.
- **Backend/API/database — Partially implemented:** Normal booking/payment creation exists in `backend/src/modules/payments/payments.service.ts` and re-resolves address/catalog/variant/add-on/coupon values server-side; no rebook-specific API, record or reuse operation was found. A normal fresh booking can be made after customer navigation, but the rebook shortcut has no server-side behavior of its own.
- **Tests and result:** No rebooking-focused test was found. `booking-flow.test.ts` exists but was not run in this targeted test command and does not establish rebook behavior from the inspected test inventory.
- **Missing behavior / next action:** Create a rebook draft from an eligible completed booking; preserve only currently valid choices; fetch current price/availability; explicitly confirm address/time and create a distinct booking with a new idempotency key. Test unavailable/archived service or variant, changed price, old address, double tap and duplicate-payment prevention.

## 6. Service guarantee and issue resolution

**Overall: Partially implemented.** Warranty terms and a generic booking dispute flow exist, but no warranty-specific claim workflow or customer-submitted claim photos were found.

- **Customer app — Partially implemented:** `service_detail_page.dart` displays `warrantyDays`/`warrantyText`, checkout shows “Protected by Veedufix Guarantee,” and `booking_detail_page.dart` lets a customer raise and track a generic dispute. The UI states a 48-hour dispute window. The dispute submission accepts a text reason; no claim-photo upload is attached to the dispute.
- **Partner app — Missing as a warranty-claim workflow:** No Partner claim response/evidence/decision flow was found. Ordinary job photo and support functions do not implement warranty claim management.
- **Admin panel — Partially implemented:** `catalog_manager_page.dart` configures warranty days/text. `disputes_queue_page.dart` and `dispute_detail_page.dart` let Admin inspect and resolve general disputes with refund/rejection and a note; the dispute detail can show Partner before/after job photos. No warranty-specific claim type, warranty policy/deadline configuration, claim evidence upload, rework outcome or warranty decision controls were found.
- **Backend/API/database — Partially implemented:** `backend/src/modules/dispute/dispute.routes.ts` supports customer create/read and Admin list/detail/resolve. `dispute.service.ts` checks booking ownership, completed job state and the configured generic 48-hour dispute cutoff; it blocks duplicate open disputes and records refund/reject resolution and note. Prisma `Dispute` has reason/status/resolution fields, but no warranty linkage, claim deadline snapshot, customer evidence attachments or rework resolution. `Service.warrantyDays` and `warrantyText` are catalog fields; no code tying these fields to claim eligibility was found.
- **Tests and result:** `backend/src/__tests__/dispute.service.test.ts` exercises generic dispute rules and passed in the targeted run. It does not prove warranty-specific eligibility or photo evidence. No customer/Admin end-to-end claim test was found.
- **Missing behavior / next action:** Define the guarantee policy and claim deadline; connect claim eligibility to the booking’s purchased service/warranty snapshot; allow authorized photo/description submission; expose claim status and decisions to Customer/Partner/Admin; record reason, deadline, timestamps, resolution/rework/refund and actor in an audit trail. Test expired warranty, wrong customer, non-completed booking, manipulated booking IDs and claim/photo authorization.

## Existing tests inspected and actually executed

Inspected focused test files before running:

- `backend/src/__tests__/upload.test.ts` — adjacent Partner work-photo upload/access behavior.
- `backend/src/__tests__/custom-quote.service.test.ts` — quote read authorization only.
- `backend/src/__tests__/dispute.service.test.ts` — generic dispute eligibility and resolution behavior.

Executed from `backend`:

```text
npm test -- src/__tests__/upload.test.ts src/__tests__/custom-quote.service.test.ts src/__tests__/dispute.service.test.ts

Test Files  3 passed (3)
Tests       19 passed (19)
Duration    1.31s
```

This is unit-test evidence for those tested backend functions; it is not end-to-end proof of any complete feature. No Flutter/Admin test, build, analyzer, staging flow, external storage/provider integration, or mobile background-location test was run. No recurring or rebooking test was found. No tracking-specific test was found. Do not infer those features are verified from the passing backend tests.

## Findings by completion status

- **Implemented and verified end-to-end:** None.
- **Implemented — unverified as a complete feature:** None; each feature has a material gap in the requested end-to-end behavior. Several component implementations exist, as detailed above.
- **Partially implemented:** Photo-assisted booking; live tracking/ETA; digital quotations/customer approval; one-tap rebooking; service guarantee/issue resolution.
- **Missing:** Recurring home maintenance.
- **Blocked:** None of the six is classified Blocked based on current access. External staging/device services were not exercised, so their behavior remains unverified rather than blocked.

## Highest-priority genuine gaps

1. **Quotation approval is broken at the Customer API boundary:** app paths do not match backend routes. The backend also does not tie approval to additional-work execution/payment, so this is the strongest immediate functional/control gap.
2. **No end-to-end proof for live tracking, and no ETA/reconnect/background support:** current customer tracking is real-time while connected; Admin map is polled persisted location and may be stale.
3. **No customer problem photos before booking:** existing photo features are Partner job documentation or post-booking chat attachments.
4. **No warranty-specific claim workflow:** a generic 48-hour dispute is not the configured service warranty/guarantee process.
5. **No recurring booking system:** the “repeat” profile copy routes to saved services, not scheduled recurrence.
6. **Book Again is navigation-only:** it reopens current service/search, not a rebook draft that carries prior options and prompts for current details.

## Infrastructure and access limits

The repository and local backend unit tests were available. No staging credentials/device session or external media/payment credentials were used. The audit did not query production data, upload to Cloudinary, connect a real WebSocket/device GPS stream, execute a payment, or test Android/iOS background behavior. These limitations prevent end-to-end verification; they do not imply the relevant deployed services are down.
