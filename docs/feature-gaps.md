# VeeduFix confirmed feature gaps

Audit date: 2026-10-09. This document lists only functionality confirmed missing or partially implemented in inspected source. Items that are merely untested or whose deployment state is unknown are documented in `launch-readiness.md`, not presented here as code gaps.

## Confirmed missing

### Customer account deletion/request workflow — P1

- **Finding:** Customer settings/support exists, but no customer account deletion API or complete deletion-request workflow was found. Settings directs the customer to support.
- **Risk:** Customers lack a clear in-product route to request account deletion; operational handling, identity confirmation, legal retention and audit rules are not represented by a dedicated flow.
- **Recommended work:** Define deletion vs. deactivation and retention policy; add authenticated request/cancel/status flow; apply required anonymization and legal holds; audit the action; notify the customer; add backend and Flutter tests.
- **Dependencies:** Product/legal retention policy; support/admin ownership; booking/payment record retention requirements.

## Confirmed partial implementations

### Location normalization — P0 data integrity

- **Finding:** Normalized state, district, city and pincode entities and service-area pincode relations exist, but saved-address records still retain free-text city/pincode fields, and some customer/Partner profile location references remain denormalized. The normalized-location migration exists, but this audit did not inspect live backfill integrity.
- **Risk:** Text and normalized IDs can drift, affecting pincode eligibility, reporting and customer address display.
- **Recommended work:** Inventory every persisted location reference; migrate addresses to normalized foreign keys with safe backfill; retain display snapshots only where needed; validate old rows, indexes and foreign keys; add migration tests and live data reconciliation.
- **Dependencies:** Existing address data quality and deployed migration state. Do not remove legacy fields until data is reconciled and clients are migrated.

### Marketplace finance/commission accounting — P1

- **Finding:** Payment, wallet, payout, refund, tax and finance records/pages exist. A complete commission/accounting reconciliation workflow was not established from inspected implementation.
- **Risk:** Admin may not have one verifiable way to reconcile customer gross amounts, tax, platform commission, Partner payable, refund and provider settlement.
- **Recommended work:** Define ledger invariants and commission rules; expose a reconciliation report; link each booking/payment/refund/payout to immutable ledger entries; compare report totals with provider settlement exports; add edge-case tests.
- **Dependencies:** Finance policy, tax treatment, provider settlement fields and accountant review.

### Admin role granularity — P2, unless multiple staff roles are needed at launch

- **Finding:** Basic CUSTOMER/WORKER/ADMIN role protection exists. A granular Admin permission matrix and UI for scoped roles were not found.
- **Risk:** Any Admin account may have broad access to customer data, financial actions and catalog/operations controls.
- **Recommended work:** If more than one trusted full-access Admin is not acceptable, define roles (for example support, catalog, finance, operations), enforce server-side action permissions, expose role assignment securely, and audit role changes.
- **Dependencies:** Staff operating model and least-privilege policy. This is not automatically a Chennai launch blocker if there is only one tightly controlled Admin account and that is an intentional policy.

### No eligible Partner recovery — P0 flow completeness

- **Finding:** Backend matching has no-candidate handling and checkout has an error state, but the full product behavior was not established: specifically, whether the customer is given an actionable alternative and whether payment remains uncaptured/refunded safely.
- **Risk:** Customer can reach a dead end or payment state can be confusing when no qualified Partner is available.
- **Recommended work:** Define the no-match state machine; prevent capture until dispatch eligibility is secured or reliably refund; offer retry/schedule/support choices; test no-candidate, partial offer acceptance, timeout and stale availability.
- **Dependencies:** Payment capture/authorization model and dispatch timeout policy.

### Customer address normalization and pincode consistency — P0

- **Finding:** Address entry and pincode validation are implemented, but persisted address models still use some free-text location columns while normalized area/pincode tables are present.
- **Risk:** The address used to show catalog eligibility may differ from the address used for checkout/matching if data changes or text is stale.
- **Recommended work:** Bind saved addresses to normalized pincode/city/area IDs, retain a display snapshot if needed, validate IDs on save and checkout, and add migration/backfill plus stale-address tests.
- **Dependencies:** Geographic normalization work above; preserve current customer addresses during migration.

### Search suggestions/autocomplete — P1, if expected as a product feature

- **Finding:** Search entry, dynamic placeholder, search results and backend catalog search exist. A distinct server-backed autocomplete/suggestion contract was not established.
- **Risk:** Customer may see only a prompt animation rather than relevant live suggestions while typing; this can reduce discovery quality.
- **Recommended work:** Confirm the intended meaning of “suggestions.” If autocomplete is required, provide debounced server-backed service/category suggestions, keyboard/accessibility behavior, location scoping and empty/error states.
- **Dependencies:** Search relevance and analytics requirements.

### Preparation instructions — P2

- **Finding:** Catalog requirement/instruction fields exist, but distinct customer-facing preparation guidance and its full Admin-to-customer mapping were not confirmed.
- **Recommended work:** Confirm whether existing fields are sufficient. If not, define a dedicated preparation field, preview it in Admin, show it in service detail/booking confirmation, and cover localization/empty cases.

## Recommended implementation order

1. **Before launch:** Verify and reconcile the migration/backfill and normalized customer address references; this protects pincode eligibility and booking correctness.
2. **Before launch:** Define and test no-eligible-Partner, timeout and payment-capture/refund outcomes; prove the exact customer-to-dispatch flow in staging.
3. **Before launch:** Define commission/ledger invariants and reconcile sample booking/payment/refund/payout flows with provider records.
4. **After launch or before broader staff access:** Add account deletion request/deactivation with retention and audit handling.
5. **As operations scale:** Add granular Admin permissions if multiple roles are needed; add autocomplete and dedicated preparation instructions based on product requirements.

## Scope note

This audit did not find sufficient evidence to classify customer rescheduling as implemented; it is labeled Unverified in the checklist. Likewise, production market state, live migration integrity, staging isolation, provider configuration and backups are verification gaps rather than confirmed source-code omissions; see `docs/launch-readiness.md`.
