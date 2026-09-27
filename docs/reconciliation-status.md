# Nile Tropical — Reconciliation Status

Date: 2026-09-27
Branch: `reconcile/live-supabase-20260927`
PR: #2 — Reconcile Flutter frontend with live Supabase backend

## State model
- LIVE VERIFIED — directly confirmed against production Supabase.
- REPOSITORY — present in GitHub.
- RECONCILED — repository changed to match live contract.
- TESTED — behavior actually tested.
- DEPLOYED — confirmed in live environment.
- UNVERIFIED — evidence still missing.

## Current matrix
| Area | Status |
|---|---|
| Production Supabase identity | LIVE VERIFIED |
| Core database schema | LIVE VERIFIED |
| create_order contract | LIVE VERIFIED / RECONCILED |
| quote_delivery | LIVE VERIFIED / RECONCILED |
| Pricing recommendation fields | LIVE VERIFIED / RECONCILED |
| app_error_logs | LIVE VERIFIED / RECONCILED |
| Payment table architecture | LIVE VERIFIED / RECONCILED |
| Checkout mock-order removal | RECONCILED |
| MTN payment transaction recording | RECONCILED IN BRANCH |
| MTN payment status reconciliation | RECONCILED IN BRANCH |
| Delivery pricing | RECONCILED |
| Tracking path | RECONCILED IN BRANCH |
| Admin Orders RPC/columns | RECONCILED |
| Admin Inventory stock RPC | RECONCILED |
| Flutter validation | TESTED — analyze, tests, web release build passed |
| Admin/CMS/frontend contract audit | PARTIAL — major screens inspected; role boundary audit remains |
| Auth/RLS contract audit | PARTIAL — live policies and role helpers inspected |
| Storage bucket/policy audit | LIVE VERIFIED — catalogue public buckets and private POD/testimonial buckets inspected |
| Edge Function version comparison | LIVE VERIFIED — deployed versions inspected; payment functions differ from reconciliation branch |
| GitHub production target | RECONCILED IN BRANCH — workflows now target `ouou...`; branch not deployed |
| Automatic production `supabase db push` safety | RECONCILED IN BRANCH — CI no longer runs database push |
| Live checkout test | PENDING |
| Live MTN test | PENDING |
| Tracking live test | PENDING |
| Email confirmation live test | PENDING |
| Merge PR #2 | NOT YET |
| Production deployment | NOT YET |

## 2026-09-27 Flutter validation result
Dedicated validation workflow completed successfully:
- `flutter pub get`: PASS
- production Supabase target check: PASS
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: PASS
- `flutter test`: PASS
- `flutter build web --release`: PASS
- No production deployment was performed by the validation workflow.

## 2026-09-27 admin/frontend contract audit
Confirmed/reconciled:
- Admin order detail uses live `update_order_status(p_order_id,p_new_status,p_note)`.
- Admin order list/detail uses `customer_name_snapshot`, not obsolete `customer_name`.
- Inventory adjustment uses live `record_stock_movement`; obsolete `adjust_stock` is not a live RPC.
- Checkout uses distance-aware `create_order` and server-side `quote_delivery`.
- Pricing uses `suggested_retail_price` and `apply_pricing_recommendation`.
- Customer and COD screens use live customer/order/COD fields.
- Delivery zone/courier creation uses live admin RPC signatures.
- CMS collection routes currently include Pages, FAQs, Testimonials, Videos and Promotions; the live schema/policy contract for each route still needs explicit final verification before merge.
- Admin analytics calls the deployed `analytics-dashboard` Edge Function and also reads order aggregates directly.

## 2026-09-27 Auth/RLS audit — important finding
The live role helper `is_staff()` currently returns true for any user who has any row in `user_roles`. A live policy inventory found **20 policies** using `is_staff()` in SELECT/ALL/UPDATE/ownership checks. This includes:
- orders and order_items
- order_status_history
- customers and customer_addresses
- shipments, delivery_events, delivery_partners, delivery_zones and couriers
- proof_of_delivery
- stock/warehouse read paths
- notification log reads
- profile staff reads
- coupon-redemption reads
- website-media staff reads

This means a user assigned a narrower role (for example courier, inventory_officer, content_manager or finance) may receive database access broader than the intended screen-by-role model. The frontend router does not substitute for database authorization.

More granular live policies already exist for:
- content management: content_manager / manager / super_admin
- pricing: manager / finance / super_admin for read/update; manager / super_admin for write
- payments/webhook events: finance / manager / super_admin
- COD: finance / manager / super_admin
- app error logs: manager / finance / super_admin
- courier shipment/event read: assigned courier or manager/super_admin

**Decision:** KEEP the current live policies unchanged for now. Do **not** redefine `is_staff()` or bulk-replace policies until the screen/action matrix proves the minimum required role for every operation. This avoids locking the production backend into an incorrect authorization model.

## Required next step — execution order
1. Complete the authoritative screen-by-screen role matrix:
   `Page → Component → Button → Flutter action → Supabase table/RPC/Edge Function → required role → live RLS policy`.
2. Audit exact operations for Orders, Inventory, Delivery, Customers, COD/Finance, Products, Pricing, CMS, Reports, Analytics, Notifications, Audit/Error logs, Courier and Management/Settings.
3. Classify each broad `is_staff()` policy as KEEP / REPAIR / REPLACE / REMOVE / NEW.
4. Only then prepare a narrow, rollback-safe RLS migration on the reconciliation branch.
5. Verify the resulting SQL and role coverage; run Supabase security/performance advisors.
6. Re-run Flutter validation.
7. Review/approve/merge only after evidence is green.
8. Deployment and real payment/tracking tests remain later steps.


## 2026-09-27 efficiency pass — read-only authorization diagnostic

A repeatable, repository-only diagnostic was added:
`supabase/diagnostics/20260927_authorization_reconciliation.sql`

It is SELECT-only and inventories:
- role helper definitions;
- public SECURITY DEFINER functions and execute grants;
- exact `pg_policies` policy names/expressions;
- every policy using `is_staff()`;
- operational-domain policies;
- aggregate role assignments;
- the live `update_order_status()` definition.

This is now the standard evidence-gathering step before any RLS migration is written. It avoids guessed policy names and avoids production role mutation.

### Function authorization verification

Live function bodies confirmed:
- `admin_create_courier()` → `delivery_ops_authorized()`
- `admin_create_delivery_zone()` → `delivery_ops_authorized()`
- `assign_shipment()` → `delivery_ops_authorized()`
- `create_shipment()` → `delivery_ops_authorized()`
- `record_stock_movement()` → super_admin / manager / inventory_officer
- `submit_proof_of_delivery()` → delivery operations or assigned courier
- `update_order_status()` → super_admin / manager / sales_staff
- `admin_upsert_product()` → super_admin / manager / inventory_officer
- `apply_pricing_recommendation()` → manager / finance / super_admin

No production function or policy was changed during this pass.

### Important live defect retained as REPAIR/PENDING

`update_order_status()` still lists `payment_failed` in its transition matrix while rejecting it in the accepted-status list. The repository migration remains a HOLD placeholder; no production change has been made.


## Safety rule
No destructive database reset, broad migration replay, automatic production migration push, payment-function replacement, or fabricated production data may be used to make repository history appear consistent.


## 2026-09-27 continued authorization/payment audit

### NEW findings
- Live payment-webhook is ACTIVE v17 but the reconciliation branch previously had no repository source for it. A repository snapshot/repair was added at supabase/functions/payment-webhook/index.ts.
- Live webhook writes order_status_history.notes, but the live column is note. The repaired branch source uses note and now checks critical write errors instead of silently returning success.
- Live update_order_status() contains payment_failed in its transition matrix but omitted it from the accepted status list. A repository migration repairs that mismatch.
- Live analytics-dashboard v5 accepts a broader set of staff roles than the documented role matrix. Branch source now limits the analytics gateway to super_admin, manager, and finance.
- Broad is_staff() policies remain LIVE and were not changed in production. A repository-only migration records narrow role replacements for operational tables; it is NOT deployed.
- Supabase production remains ououfhsswyqutcczdtnb. No production migration or Edge Function deployment was performed in this pass.

### KEEP
- Production database as source of truth.
- Function-level authorization where already enforced.
- Guest tracking and payment server authority.
- No destructive reset or role-assignment changes.

### REPAIR — repository only
- supabase/functions/payment-webhook/index.ts
- supabase/functions/analytics-dashboard/index.ts
- supabase/migrations/20260927_authorization_lifecycle_reconciliation.sql

### PENDING
- Review and test the new RLS migration with non-production role fixtures before any production application.
- Verify MTN callback authentication/signature contract; current live integration has no verified callback signature field, so gateway status reconciliation remains the independent confirmation control.
- Run Flutter validation against the latest branch head after the current commits settle.
- Re-run Supabase security/performance advisors after any eventual production RLS change.
- No deployment is authorized by this audit step.
