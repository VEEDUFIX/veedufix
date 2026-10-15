# VeeduFix feature checklist

Audit date: 2026-10-09. Scope: source, Prisma schema/migrations, API routes, and checked-in tests. No build, analyzer, or test command was run for this audit. “Implemented” means source implementation was found; it does not mean runtime-verified. “Verified” is reserved for behavior actually exercised successfully in this audit (none).

## How to read this checklist

Each row records feature, status, priority, code evidence, test evidence, and next action. Evidence paths are repository-relative. Test keys: `B-AUTH` auth/session unit and auth e2e; `B-CAT` catalog/service-area unit and catalog e2e; `B-BOOK` booking-flow/payment unit and booking e2e; `B-MATCH` matching unit (radius, qualification, online, conflicting jobs, schedules); `B-FIN` refund/webhook/wallet/payout tests; `B-OPS` operations/reviews/support tests; `C` customer Flutter tests (wallet, cart, booking OTP, home); `P` Partner Flutter tests (job repository, jobs/shell); `A` Admin Flutter test (customer management). “Not run” applies to all these suites during this audit. An em dash means no focused test was found in the inspected test inventory. P0 = launch blocker, P1 = initial reliability/operations, P2 = later enhancement.

## 1. Customer app

### Authentication and profile

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 1 | Phone number and OTP authentication | Implemented · P0 | `apps/customer_app/lib/features/auth`; backend `src/modules/auth` | B-AUTH; C booking OTP only; not run | Exercise full sign-in, resend, expiry and invalid-code cases against deployed API. |
| 2 | Session persistence and logout | Implemented · P0 | Customer auth/session providers; backend `src/lib/auth-session.ts` | B-AUTH; not run | Verify restart persistence, token rotation/revocation and logout on device. |
| 3 | Customer profile/contact information | Implemented · P1 | Customer profile pages; backend user routes/services | — | Verify edits persist and propagate to bookings/receipts. |
| 4 | Saved addresses and address management | Implemented · P0 | Customer saved-address pages/providers; backend address routes; Prisma `Address`, `SavedAddress` | — | Execute add/edit/delete/default and checkout selection flows. Address location still partly text-based; see gaps. |
| 5 | Location selection and pincode validation | Implemented · P0 | Map location picker, selected-location provider; backend service-area routes/service | B-CAT; not run | Verify GPS/manual selection, unsupported/inactive pincode rejection and checkout revalidation live. |

### Home and service discovery

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 6 | Selected service area displayed | Implemented · P0 | `home_header.dart`; selected-location provider | C home; not run | Verify selected pincode and area survive app restart and are consistent with address. |
| 7 | Dynamic search with service suggestions | Partially implemented · P1 | Customer search page; catalog search endpoint; home rotating search prompt | C home/search; not run | Search and suggestions UI exist, but dedicated server-backed autocomplete/suggestion behavior was not established. Verify UX and exact API behavior. |
| 8 | Category grid and category browser | Implemented · P1 | Customer home/category widgets; backend catalog routes | B-CAT, C home; not run | Verify category tree and deep links with empty/inactive categories. |
| 9 | Admin-controlled image-only hero banners | Implemented · P1 | Admin home banner manager; backend home-banner routes; Customer home banner widget | B-CAT, C home; not run | Confirm customer crop, tap destination and active/scheduled behavior on deployed data. |
| 10 | Most-booked services | Implemented · P1 | Home content/catalog sections; backend catalog service | B-CAT, C home; not run | Verify admin selection/order and fallback when no items are active. |
| 11 | Admin-controlled home sections and order | Implemented · P1 | Admin home sections manager; backend home section routes/schema; Prisma home section models | B-CAT, C home; not run | Verify reorder/publish and customer rendering against production API. |
| 12 | Service availability filtered by location | Implemented · P0 | Backend catalog availability/inheritance and service-area modules; customer catalog providers | B-CAT; not run | Validate behavior for parent-inherited and child-custom area rules in e2e. |
| 13 | Search results, sorting and filtering | Implemented · P1 | Customer search page; backend catalog search/query schemas | B-CAT, C; not run | Verify combined filters, sorting, pagination and location scoping. |
| 14 | Loading, empty and error states | Partially implemented · P1 | Present across customer feature pages/providers | C; not run | No systematic state-coverage evidence; exercise offline, timeout, empty catalog and retry paths. |

### Service details

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 15 | Service images and galleries | Implemented · P1 | Customer service detail; Admin catalog/image picker; Prisma service media fields | — | Verify all image formats, failed image loads and gallery ordering on device. |
| 16 | Descriptions, pricing, duration and ratings | Implemented · P0 | Service detail; backend catalog; Prisma Service/Review | B-CAT; not run | Verify displayed values match server quote and review aggregates. |
| 17 | Service variants and packages | Implemented · P0 | Service detail and cart; backend catalog/payment validation; Prisma Variant | B-CAT, B-BOOK; not run | Verify area-specific variant choices and stale variant rejection. |
| 18 | Optional add-ons | Implemented · P1 | Service detail/cart; backend catalog/payment validation; Prisma Addon | B-CAT, B-BOOK; not run | Verify selected add-ons and price are revalidated server-side. |
| 19 | What's included and excluded | Implemented · P1 | Catalog schema/Admin catalog editor and customer detail | B-CAT; not run | Verify authored content appears accurately for each service. |
| 20 | Requirements and preparation instructions | Partially implemented · P2 | Service catalog has requirements/instructions fields; customer detail consumes catalog content | B-CAT; not run | Distinct customer-facing preparation guidance was not confirmed end-to-end; verify or add dedicated field/UX if required. |
| 21 | Warranty and cancellation policy | Implemented · P1 | Catalog service fields/detail; backend booking/refund policy modules | B-BOOK, B-FIN; not run | Verify policy display matches actual cancellation/refund enforcement. |
| 22 | Reviews and related services | Implemented · P1 | Customer detail/review pages; backend reviews/catalog | B-CAT, B-OPS; not run | Verify moderation state and related-service location eligibility. |
| 23 | Favorite services | Implemented · P2 | Customer favorites feature; backend user/catalog routes | — | Verify persistence across sessions and removal behavior. |

### Booking and checkout

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 24 | Instant booking | Implemented · P0 | Customer checkout; backend payments/booking/matching modules | B-BOOK, B-MATCH; not run | Run complete customer-to-dispatch flow in staging. |
| 25 | Scheduled booking and time slots | Implemented · P0 | Checkout schedule selection; backend availability/schedule validation | B-BOOK, B-MATCH; not run | Verify slot race conditions and timezone behavior in staging. |
| 26 | Address selection and creation | Implemented · P0 | Checkout and saved-address UI; backend address/booking routes | — | Verify address mutation and booking address snapshot end-to-end. |
| 27 | Booking summary and quantity/variant selection | Implemented · P0 | Customer cart/checkout; backend quote validation | C cart; B-BOOK; not run | Verify totals refresh after cart changes and server rejects stale values. |
| 28 | Promo codes and discounts | Implemented · P1 | Customer checkout/offers; backend coupon/payment service | B-BOOK; not run | Verify eligibility, expiry, limits and concurrent redemption. |
| 29 | Transparent pricing and taxes | Implemented · P0 | Checkout price summary; backend payment/tax calculations | B-BOOK; not run | Reconcile displayed total, tax and provider capture in staging. |
| 30 | Payment initiation and confirmation | Implemented · P0 | Customer checkout; backend payment and verified webhook modules | B-BOOK, B-FIN; not run | Verify real provider test-mode success, webhook signature and final booking state. |
| 31 | Payment failure and retry | Implemented · P0 | Checkout retry/verification states; backend payment/refund flow | B-BOOK, B-FIN; not run | Exercise provider timeout, declined payment and retry without duplicate charge. |
| 32 | Duplicate booking/payment prevention | Implemented · P0 | Backend idempotency/booking/payment logic; DB constraints | B-BOOK; not run | Confirm idempotency under concurrent requests against staging DB/provider. |
| 33 | Server-side location and availability validation | Implemented · P0 | Payment/booking service resolves address, area, service, option and schedule | B-BOOK, B-CAT; not run | Verify manipulated/stale client IDs are rejected in end-to-end tests. |
| 34 | No eligible Partner scenario | Partially implemented · P0 | Backend matching/booking has no-match handling; customer checkout error state | B-MATCH, B-BOOK; not run | Confirm customer gets actionable error and payment is not captured when dispatch has no eligible Partner. |

### Booking management

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 35 | Upcoming and active bookings | Implemented · P0 | Customer bookings page; backend booking/user routes | C booking OTP; not run | Verify booking list refresh and server status mapping. |
| 36 | Booking status and timeline | Implemented · P1 | Booking detail/timeline; backend booking/job execution models | — | Validate all transition events and ordering from live API. |
| 37 | Partner details when appropriate | Implemented · P1 | Booking detail/tracking; backend booking response includes worker data | — | Verify details are hidden until assignment and privacy is maintained. |
| 38 | Cancellation and refund status | Implemented · P0 | Booking detail/cancellation; backend refund/dispute services | B-FIN, B-BOOK; not run | Verify cancellation cutoffs, refund outcomes and UI status against provider. |
| 39 | Rescheduling | Unverified · P2 | No complete customer rescheduling flow confirmed in inspected pages/routes | — | Confirm whether rescheduling is intentionally unsupported; if required, implement server-validated change flow. |
| 40 | Contact/support options | Implemented · P1 | Customer support/chat pages; backend support/chat routes | B-OPS; not run | Verify ticket creation/contact escalation from each booking state. |
| 41 | Service completion confirmation | Implemented · P1 | Completion OTP page; backend worker execution/booking routes | B-BOOK; not run | Verify OTP replay protection and completion audit trail. |
| 42 | Rating and review submission | Implemented · P1 | Customer booking rating; backend review routes/service | B-OPS; not run | Verify one-review policy, completed-booking requirement and moderation. |
| 43 | Booking history and receipts | Implemented · P1 | Booking history; backend invoice routes/service | B-BOOK; not run | Verify invoice generation/download and historical booking access. |

### Customer account

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 44 | Profile editing | Implemented · P1 | Customer profile/settings; backend users routes | — | Verify updates and validation. |
| 45 | Notifications | Implemented · P1 | Customer notification center; backend notifications/device tokens | B-OPS; not run | Verify push delivery, permission denial and read state. |
| 46 | Help and support | Implemented · P1 | Support page/chat; backend support routes | B-OPS; not run | Verify support routing, staff response and failure handling. |
| 47 | Privacy and account settings | Partially implemented · P1 | Settings/privacy screens and backend user settings | — | Review actual privacy choices and ensure data access/deletion obligations are covered. |
| 48 | Account deletion flow | Missing · P1 | No customer deletion endpoint/confirmed deletion workflow found; settings directs users to support | — | Add a verified deletion/request workflow with retention, booking/finance legal holds and audit behavior. |

## 2. Partner app

### Authentication and onboarding

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 49 | Phone and OTP authentication | Implemented · P0 | Partner auth pages; shared backend auth/session | B-AUTH, P; not run | Exercise OTP/login/session against staging. |
| 50 | Progressive onboarding with resume support | Implemented · P0 | `features/onboarding` flow/provider; backend worker-onboarding service | P; not run | Verify resume after process kill and after server-side step save. |
| 51 | Personal and emergency-contact information | Implemented · P1 | Onboarding/profile forms; worker profile schema | — | Verify required-field validation and persistence. |
| 52 | Services, skills and experience | Implemented · P0 | Onboarding skill/service forms; backend worker onboarding and qualification | B-MATCH, P; not run | Verify only approved qualifications enter matching. |
| 53 | Service areas and pincodes | Implemented · P0 | Partner area form; normalized service-area assignment models/routes | B-MATCH; not run | Verify multiple-pincode assignment and admin-review constraints live. |
| 54 | Individual travel radius | Implemented · P0 | Worker profile radius field; matching service applies per-Partner radius | B-MATCH (within/outside/different radii); not run | Verify configured radius persistence and default behavior in staging. |
| 55 | Working days and hours | Implemented · P0 | Worker availability screens/provider; backend availability/schedule models | B-MATCH, P; not run | Verify schedule changes affect candidate selection immediately. |
| 56 | Identity and professional-document verification | Implemented · P0 | Onboarding document capture/status; backend worker documents/review | B-OPS; not run | Verify secure upload, review states and rejection/resubmission flow. |
| 57 | Bank and payout setup | Implemented · P0 | Partner earnings/profile payout pages; backend payout routes/models | B-FIN; not run | Verify ownership checks, encryption/provider handling and payout change approval. |
| 58 | Terms acceptance | Implemented · P1 | Onboarding flow has acceptance step; worker onboarding schema/service | — | Verify versioned consent evidence and timestamp persistence. |
| 59 | Admin approval and account status | Implemented · P0 | Admin worker review; backend onboarding review/status routes | B-OPS, P; not run | Verify only approved/active accounts can receive dispatch offers. |

### Dashboard and job management

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 60 | Online/offline availability | Implemented · P0 | Partner dashboard/availability provider; backend worker availability | B-MATCH, P; not run | Verify offline transitions invalidate or suppress new offers. |
| 61 | New job requests | Implemented · P0 | Jobs/dashboard pages; backend dispatch offer routes/models | B-MATCH, P; not run | Test push, polling/reconnect and offer expiry on device. |
| 62 | Accept and decline flows | Implemented · P0 | Job pages/provider; backend matching/worker job routes | B-MATCH, P; not run | Verify competing accept requests are atomic and user feedback is clear. |
| 63 | Request expiration and timeout | Implemented · P1 | Dispatch offer expiry/status fields and backend sweeper/dispatch logic | B-MATCH; not run | Verify scheduled expiry and late acceptance behavior in staging. |
| 64 | Upcoming and active jobs | Implemented · P0 | Jobs/dashboard pages; backend worker job routes | P; not run | Verify state transitions and list refresh. |
| 65 | Job details and customer location | Implemented · P0 | Job execution/details pages; backend booking response | P; not run | Verify access is limited to assigned Partner and location is appropriately disclosed. |
| 66 | En-route, arrived and in-progress states | Implemented · P1 | Job execution page/provider; backend execution state transitions | B-BOOK, P; not run | Exercise every allowed transition and invalid transition. |
| 67 | Job completion workflow | Implemented · P0 | Execution page, completion OTP, quote/parts where supported | B-BOOK, P; not run | Verify OTP, evidence and payment/booking state consistency. |
| 68 | Cancellation and no-show handling | Implemented · P1 | Job execution/cancellation routes and dispute models | B-OPS, P; not run | Verify penalties, customer notification and refund/exception handling. |
| 69 | Conflicting-job prevention | Implemented · P0 | Backend matching schedule/active-job checks | B-MATCH; not run | Verify under concurrent offer acceptance and booking changes. |
| 70 | Notifications and booking updates | Implemented · P1 | Partner notification pages; backend notification/device-token routes | B-OPS; not run | Verify device delivery and notification-to-job deep links. |
| 71 | Empty, loading and error states | Partially implemented · P1 | State handling across dashboard/jobs/providers | P; not run | Run offline/timeout/empty scenarios; verify actionable recovery. |

### Earnings and profile

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 72 | Earnings summary and history | Implemented · P1 | Earnings and wallet pages; backend finance/payout services | B-FIN; not run | Reconcile balances against ledger and completed bookings. |
| 73 | Payout status and records | Implemented · P0 | Earnings/payout UI; backend payout service and provider-attempt records | B-FIN; not run | Verify settlement lifecycle with provider sandbox/live config. |
| 74 | Secure payout-account changes | Implemented · P0 | Payout change request UI/Admin queue; backend approval and audit models | B-FIN, B-OPS; not run | Verify authorization, notification and old/new account controls. |
| 75 | Service and skill management | Implemented · P1 | Partner onboarding/profile; backend worker qualification routes | B-MATCH; not run | Verify approved Partner cannot silently alter required qualifications. |
| 76 | Service-area editing | Implemented · P1 | Partner area profile; backend review guard and Admin assignment routes | B-MATCH; not run | Verify unchanged IDs allow unrelated edits and changed assignments require review. |
| 77 | Availability editing | Implemented · P0 | Availability page/provider; backend availability service | B-MATCH, P; not run | Verify schedule overlap validation and matching effect. |
| 78 | Professional portfolio | Implemented · P2 | Onboarding portfolio/document/media flow | — | Verify upload and public visibility; not launch-critical unless sales depend on it. |
| 79 | Ratings and reviews | Implemented · P1 | Partner reviews page; backend reviews/response/moderation routes | B-OPS; not run | Verify only eligible reviews appear and responses are moderated. |
| 80 | Help and support | Implemented · P1 | Partner support feature; backend support routes | B-OPS; not run | Verify ticket creation and escalation. |
| 81 | Device/session security | Partially implemented · P1 | Shared auth sessions/device token routes; Partner settings | B-AUTH; not run | Verify session revocation on logout/account suspension and lost-device recovery. |

## 3. Admin panel

### Dashboard and operations

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 82 | Business and booking overview | Implemented · P1 | Admin analytics/ops overview; backend analytics routes | B-OPS, A; not run | Reconcile metrics with source records and role scope. |
| 83 | Booking search and filters | Implemented · P1 | Booking management page; backend booking/admin routes | B-BOOK; not run | Verify combined filters, pagination and export if required. |
| 84 | Booking status management | Implemented · P0 | Booking management actions; backend booking/ops services | B-BOOK; not run | Verify transition permissions and audit trail. |
| 85 | Customer management | Implemented · P1 | Customer management/detail pages; backend admin user routes | A; not run | Test suspend/reactivate and PII access audit. |
| 86 | Partner directory and approval | Implemented · P0 | Worker directory/review pages; backend onboarding/directory routes | B-OPS, A; not run | Verify documents and approval state against matching eligibility. |
| 87 | Partner suspension/reactivation | Implemented · P0 | Worker detail/admin actions; backend admin user/onboarding routes | B-OPS; not run | Verify suspension immediately prevents dispatch and records actor/reason. |
| 88 | Partner-service qualification | Implemented · P0 | Worker review/directory; backend worker qualification models/routes | B-MATCH; not run | Verify assignment and approval are enforced in matching. |
| 89 | Partner-to-area assignments | Implemented · P0 | Service area manager/worker detail; backend area assignment routes | B-MATCH; not run | Verify assignment changes and city/area summary integrity. |
| 90 | Support and complaint handling | Implemented · P1 | Support tickets/dispute queues; backend support/dispute routes | B-OPS; not run | Verify end-to-end assignment, SLA and closure notification. |

### Service catalog management

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 91 | Categories and subcategories | Implemented · P0 | Catalog manager; backend catalog routes/schema; Prisma category models | B-CAT; not run | Verify publish and inherited availability semantics. |
| 92 | Service create/edit/duplicate/archive | Implemented · P0 | Catalog manager workflows; backend catalog routes | B-CAT; not run | Verify each operation and archive behavior against existing bookings. |
| 93 | Variants and packages | Implemented · P0 | Catalog manager; backend Variant model/catalog/payment validation | B-CAT, B-BOOK; not run | Verify area-specific option editing and price snapshots. |
| 94 | Add-ons | Implemented · P1 | Catalog manager; backend Addon/catalog/payment modules | B-CAT, B-BOOK; not run | Verify add-on eligibility and quote. |
| 95 | Images and image previews | Implemented · P1 | Shared Admin image picker; catalog and banner editors | — | Exercise upload/replace/remove, supported formats and failed storage responses. |
| 96 | Customer-view preview | Partially implemented · P1 | Banner preview/crop UI and catalog previews | — | Confirm all catalog edits preview actual customer rendering/crop before publish. |
| 97 | Pricing and discount configuration | Implemented · P0 | Catalog/coupon/finance Admin pages; backend pricing/payment services | B-BOOK, B-FIN; not run | Verify Admin-entered prices and discounts reconcile with server quote. |
| 98 | Service duration and booking rules | Implemented · P0 | Catalog manager fields; backend availability/payment validation | B-CAT, B-BOOK; not run | Verify duration and booking constraints affect slots/matching. |
| 99 | Requirements, inclusions, exclusions and warranty | Implemented · P1 | Catalog editor/schema; customer service detail | B-CAT; not run | Verify each field is exposed consistently and policy matches enforcement. |
| 100 | Reviews and ratings moderation | Implemented · P1 | Review moderation page/API; backend moderation routes/service | B-OPS; not run | Verify moderation audit and customer/Partner visibility. |
| 101 | Search keywords and synonyms | Implemented · P2 | Catalog search metadata/schema and Admin editor | B-CAT; not run | Verify synonym indexing and relevance from customer search. |
| 102 | Drag-and-drop display ordering | Implemented · P1 | Catalog manager reorder controls; backend sort fields/routes | B-CAT; not run | Verify persisted ordering after reload and concurrent edits. |
| 103 | Draft, preview, publish and scheduling | Implemented · P1 | Catalog and home banner managers; backend active/schedule fields | B-CAT; not run | Verify start/end boundary, timezone and unpublished content behavior. |
| 104 | Bulk catalog operations | Implemented · P1 | Catalog manager bulk availability/copy/apply flows with confirmation | B-CAT; not run | Verify filtered scope, confirmation and rollback on partial failure. |

### Home content management

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 105 | Hero-banner upload and crop preview | Implemented · P1 | Home banner manager and Admin image picker; backend home-banner route | — | Confirm crop matches customer widget at supported widths. |
| 106 | Admin-controlled banner destination | Implemented · P1 | Banner destination fields/API and customer tap router | B-CAT; not run | Verify each destination type and invalid/deleted destination fallback. |
| 107 | Category ordering | Implemented · P1 | Catalog manager category sort controls; backend catalog sort fields | B-CAT; not run | Verify ordering persisted to customer grid. |
| 108 | Most-booked service selection | Implemented · P1 | Home section manager and backend section items | B-CAT; not run | Verify selection/admin order and customer output. |
| 109 | Dynamic home-section creation | Implemented · P2 | Home section manager/API/model | B-CAT; not run | Verify section types, empty state and customer rendering. |
| 110 | Service selection per section | Implemented · P1 | Home section item editor/API | B-CAT; not run | Verify inactive/unavailable services are filtered for customer. |
| 111 | Active/inactive, publishing and preview controls | Implemented · P1 | Home banner/section managers and backend active/schedule fields | B-CAT; not run | Verify scheduled publish and deactivate behavior against live app. |

### Geographic management

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 112 | State and district records | Implemented · P1 | Prisma `GeoState`/`GeoDistrict`; service-area manager/API | B-CAT; not run | Verify deployed lookup records and foreign-key integrity. |
| 113 | Cities and service areas | Implemented · P0 | Prisma `City`/`ServiceArea`; Admin service-area manager and routes | B-CAT; not run | Verify active service-area hierarchy in deployed database. |
| 114 | Pincodes and multiple-pincode assignments | Implemented · P0 | Prisma `GeoPincode`/`ServiceAreaPincode`; migrations `20261009120000` and `20261014120000` | B-CAT; not run | User supplied successful migrate-deploy output; independently inspect backfill and live assignments before launch. |
| 115 | Location activation/deactivation | Implemented · P0 | Service-area manager and backend active fields/checks | B-CAT; not run | Verify inactive area blocks catalog, checkout and matching consistently. |
| 116 | Category availability inheritance | Implemented · P0 | `backend/src/modules/catalog/availability-inheritance.ts`; catalog manager | B-CAT; not run | Verify category→descendant effective availability for inherited/custom rules. |
| 117 | Subcategory availability inheritance | Implemented · P0 | Availability inheritance service and catalog editor | B-CAT; not run | Test override precedence and removal of override. |
| 118 | Service/variant custom overrides | Implemented · P0 | Catalog availability fields and backend availability/payment validation | B-CAT, B-BOOK; not run | Test variant filtering again at quote and checkout. |
| 119 | Combined catalog filters | Implemented · P1 | Catalog manager location/category/status filter controls | B-CAT; not run | Verify all geography and catalog filters compose and preserve scope. |
| 120 | Bulk availability management | Implemented · P1 | Catalog bulk apply/copy/remove actions; confirmation dialog | B-CAT; not run | Verify selected scope, destructive confirmation and atomic outcomes. |
| 121 | Launch-market configuration | Implemented · P0 | Seed config sets Chennai active and Bengaluru/Hyderabad inactive; market data in schema | B-CAT; not run | Live active markets and pincodes were not inspected; confirm current DB values. |
| 122 | Chennai-only launch without hardcoded Chennai logic | Implemented · P0 | Seed/configuration-based market activation; no matching rule hardcodes Chennai found in inspected source | B-CAT, B-MATCH; not run | Confirm deployed market configuration and a non-Chennai inactive pincode end-to-end. |

### Financial and administrative controls

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 123 | Pricing and tax configuration | Implemented · P0 | Admin catalog/tax pages; backend payment/tax logic | B-BOOK, B-FIN; not run | Verify tax settings and final customer/ledger amounts with provider sandbox. |
| 124 | Payment and refund tracking | Implemented · P0 | Admin refund ledger; backend payment/refund/webhook modules | B-FIN; not run | Verify provider status reconciliation and webhook replay/stale-event handling in staging. |
| 125 | Partner earnings and settlements | Implemented · P0 | Admin payout ledger; backend payout/wallet/finance services | B-FIN; not run | Reconcile actual settlement ledger against provider records. |
| 126 | Marketplace commission/accounting records | Partially implemented · P1 | Backend payment, wallet, payout and finance records; tax/payout Admin views | B-FIN; not run | No complete accounting/commission reconciliation evidence or full Admin commission workflow was established. Define and verify ledger reconciliation. |
| 127 | Audit history for sensitive changes | Implemented · P1 | Backend audit helpers/models/routes; Admin audit surface | B-OPS; not run | Verify coverage for every sensitive mutation and actor attribution. |
| 128 | Admin roles and permissions | Partially implemented · P2 | Backend role authorization has CUSTOMER/WORKER/ADMIN; Admin routes protected | B-AUTH; not run | Granular Admin role/permission matrix and Admin UI were not found. Confirm single-admin operational policy or implement least privilege. |
| 129 | Confirmation for destructive operations | Implemented · P1 | Shared Admin confirmation dialog and bulk-operation confirmations | — | Verify all archive/delete/suspend/refund actions use the confirmation and audit actor/reason. |

## 4. Backend and infrastructure

| # | Feature | Status / priority | Evidence | Test evidence | Gap / next action |
|---|---|---|---|---|---|
| 130 | Authentication and authorization | Implemented · P0 | `backend/src/modules/auth`, `src/lib/auth-session.ts`, route middleware | B-AUTH; not run | Verify deployed secrets, session revocation and abuse controls. |
| 131 | Role-based access control | Partially implemented · P0 | User role enum and protected route middleware | B-AUTH; not run | Basic customer/worker/admin roles exist; granular Admin least privilege absent. |
| 132 | Customer, Partner and Admin API protection | Implemented · P0 | Auth/role guards across mounted routes | B-AUTH, B-OPS; not run | Run negative authorization tests for all sensitive route groups. |
| 133 | Database relations, constraints and indexes | Implemented · P0 | `backend/prisma/schema.prisma`, migrations | Schema validation not run | Independently inspect live constraints/indexes and migration state. |
| 134 | Location normalization and migrations | Partially implemented · P0 | Geo state/district/pincode, City and service-area pincode FKs/migrations | B-CAT; not run | Customer saved addresses and some profile fields remain text-based; verify backfill and referential integrity. |
| 135 | Catalog and availability APIs | Implemented · P0 | `src/modules/catalog`, `availability`, `service-area` | B-CAT; not run | Verify all customer queries use effective inherited area availability. |
| 136 | Booking eligibility validation | Implemented · P0 | `src/modules/payments/payments.service.ts` validates address, service, options and schedule | B-BOOK; not run | Exercise tampered IDs and stale prices in end-to-end staging flow. |
| 137 | Partner matching and individual radius | Implemented · P0 | `src/modules/matching/matching.service.ts` checks individual `serviceRadiusKm` with safe default | B-MATCH; not run | Tests are present, but not run here; verify location coordinate quality on deployed profiles. |
| 138 | Schedule and conflicting-job checks | Implemented · P0 | Matching/availability services and active booking/job checks | B-MATCH; not run | Test concurrent acceptance and time-boundary cases. |
| 139 | Payment integration and verified webhooks | Implemented · P0 | Payments service and webhook signature verification | B-BOOK, B-FIN; not run | Confirm provider credentials, webhook endpoint configuration and replay behavior in staging. |
| 140 | Idempotency and duplicate-request prevention | Implemented · P0 | Payment/booking idempotency logic and DB constraints | B-BOOK; not run | Verify concurrent retries and provider idempotency behavior. |
| 141 | Notifications and delivery failure handling | Implemented · P1 | Notification, device-token, push and ops routes/models | B-OPS; not run | No live delivery proof; validate retries/dead-letter or explicit failed-delivery visibility. |
| 142 | Image storage and delivery | Implemented · P1 | Cloudinary/configured media service and Admin upload component | — | Verify access controls, size limits, CDN availability and production bucket configuration. |
| 143 | Logging, monitoring and actionable errors | Implemented · P1 | Pino/Sentry integration, request scrubbing, health/ops routes | B-OPS; not run | Confirm production alerting, retention and error ownership. |
| 144 | Rate limiting and abuse protection | Implemented · P1 | Rate-limit helpers and endpoint-specific auth/OTP limits | B-AUTH; not run | Verify production store/config and thresholds under load. |
| 145 | Secrets and environment configuration | Implemented · P0 | `src/config/env.ts`, environment validation and production placeholder checks | — | Verify deployed secret values/rotation without exposing them; no secret values inspected. |
| 146 | Database backups and recovery procedure | Unverified · P0 | No evidence of an executed restore drill or verified backup schedule in inspected repo/deployment config | — | Obtain backup retention proof and complete a restore drill before public launch. |
| 147 | Staging/production separation | Unverified · P0 | Render/Vercel configs exist; staging evidence is limited to test/load docs, no independent deployed environment proof | — | Verify distinct databases, credentials, payment keys, domains and deployment workflows. |

## 5. Geography and Partner-matching acceptance flow

Acceptance flow under review: Admin activates a Chennai service area → publishes a service for that area → assigns an approved Partner with the required skill and radius → customer selects an eligible pincode → catalog shows eligible service → checkout revalidates → matcher checks service area, qualification, individual radius, online status, schedule and active-job conflicts → eligible Partner receives the request.

Source implementations exist for the constituent rules. The full flow was **not executed** against staging or production during this audit, so the acceptance criteria below are not marked Verified.

| Acceptance case | Current evidence | Status | Required verification |
|---|---|---|---|
| Supported Chennai pincode and active service area | Area/pincode lookup and catalog availability code; B-CAT | Implemented, unverified | Create/confirm active test area and prove catalog + checkout eligibility. |
| Unsupported pincode | Service-area resolution and booking validation; B-CAT/B-BOOK | Implemented, unverified | Assert customer catalog is empty/clear and checkout returns a safe error. |
| Inactive service area | Active-area checks in catalog/booking/matching; B-CAT/B-BOOK/B-MATCH | Implemented, unverified | Deactivate and prove checkout and matching reject it. |
| Inactive service | Catalog active filters and payment validation; B-CAT/B-BOOK | Implemented, unverified | Manipulate client request for inactive service; server must reject. |
| Partner outside own radius | Individual radius condition and matching unit cases; B-MATCH | Implemented, unverified | Run tests including two Partners with different radii; verify no outside candidate. |
| Partner lacks required skill | Worker service qualification predicate and matching unit cases; B-MATCH | Implemented, unverified | Verify unqualified candidate never receives offer. |
| Partner offline/unavailable | Candidate availability predicate and matching unit cases; B-MATCH | Implemented, unverified | Verify offline/unavailable candidate rejected at dispatch time. |
| Conflicting active job or schedule | Matching active-job/schedule checks and unit cases; B-MATCH | Implemented, unverified | Verify conflict case including concurrent acceptance/race. |
| No eligible Partner | Matcher no-candidate handling; B-MATCH/B-BOOK | Partially implemented, unverified | Verify customer messaging, no charge/capture and safe booking state. |
| Stale/manipulated client data | Server-side catalog/address/variant/price resolution; B-BOOK | Implemented, unverified | Test stale IDs, altered price, wrong pincode and unavailable variant. |

## Audit limits

This document reports inspected source and checked-in test inventory, not successful runtime behavior. Builds, `flutter analyze`, Flutter/backend/Admin tests, migration validation against live database, service smoke tests, provider test-mode payment, and disaster-recovery checks were not run in this audit. Do not treat source presence or a prior user-pasted command result as independent verification.
