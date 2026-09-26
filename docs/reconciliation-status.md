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
| MTN payment transaction recording | RECONCILED |
| MTN payment status reconciliation | RECONCILED |
| Delivery pricing | RECONCILED |
| Tracking path | RECONCILED |
| Auth/RLS contract audit | PARTIAL — core order/payment/pricing/error policies verified; full Flutter path audit pending |
| Storage bucket/policy audit | LIVE VERIFIED — public catalogue buckets, private POD/testimonial buckets, staff/courier policies inspected |
| Edge Function version comparison | LIVE VERIFIED — deployed versions inspected; payment functions differ from reconciliation branch |
| GitHub production target | RECONCILED IN BRANCH — workflows now target `ouou...`; branch not deployed until merge |
| Automatic production `supabase db push` safety | RECONCILED IN BRANCH — CI no longer runs database push |
| Flutter analyze | PENDING — not yet run |
| Flutter tests | PENDING |
| Flutter web build | PENDING |
| Live checkout test | PENDING |
| Live MTN test | PENDING |
| Tracking live test | PENDING |
| Email confirmation live test | PENDING |
| Merge PR #2 | NOT YET |
| Production deployment | NOT YET |

## Immediate sequence
1. Finish admin/delivery/inventory/Auth/RLS contract audit and verify checkout/payment frontend paths.
2. Review the new transaction-binding/payment-lifecycle and public-tracking fixes in the reconciliation branch.
3. Run Flutter analyze/tests/build and Edge Function source validation.
4. Compare/deploy Edge Functions only after code review and controlled verification.
5. Perform controlled end-to-end checkout, MTN, tracking and notification tests.
6. Merge only after evidence is green.
7. Deploy and verify production behavior.


## Safety rule
No destructive database reset, broad migration replay, or payment-function replacement should occur merely to make repository history look consistent.