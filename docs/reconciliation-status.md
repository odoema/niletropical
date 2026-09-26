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
| Auth/RLS full frontend audit | UNVERIFIED |
| Storage full policy audit | UNVERIFIED |
| Edge Function version comparison | UNVERIFIED |
| GitHub production target | BLOCKED — workflow still references `tyhq...` |
| Automatic production `supabase db push` safety | BLOCKED — review required |
| Flutter analyze | PENDING |
| Flutter tests | PENDING |
| Flutter web build | PENDING |
| Live checkout test | PENDING |
| Live MTN test | PENDING |
| Tracking live test | PENDING |
| Email confirmation live test | PENDING |
| Merge PR #2 | NOT YET |
| Production deployment | NOT YET |

## Immediate sequence
1. Finish admin/delivery/inventory/Auth/RLS/Storage contract audit.
2. Correct GitHub deployment targets to the verified production project.
3. Remove or gate automatic production database migration pushing until migration history is reconciled.
4. Run Flutter analyze/tests/build.
5. Compare repository Edge Functions with deployed production versions.
6. Perform controlled end-to-end tests.
7. Merge only after evidence is green.
8. Deploy and verify production behavior.

## Safety rule
No destructive database reset, broad migration replay, or payment-function replacement should occur merely to make repository history look consistent.