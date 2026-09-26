# Nile Tropical — AI Engineering Handoff

Shared engineering state: GitHub repository `odoema/niletropical`
Production backend authority: Supabase `ououfhsswyqutcczdtnb`

## Collaboration protocol
This repository is the shared state between the GitHub-connected and Supabase-connected engineering sessions.

### Supabase-connected session
- verify live production schema;
- verify RPC signatures and behavior;
- verify RLS and Auth;
- verify Storage;
- verify deployed Edge Functions;
- record only directly verified production facts.

### GitHub-connected session
- audit Flutter and Edge Function source;
- reconcile source with the verified backend contract;
- run repository tests/builds;
- prepare controlled commits and PRs;
- never treat a migration file as proof of production state.

### User
Final controller and approval authority for merge/deployment decisions.

## Shared truth rule
Supabase tells us what is live. GitHub tells us what is implemented.

## Current production identity
`ououfhsswyqutcczdtnb`

The `tyhqwngqxbcivfphgxck` target currently present in GitHub workflows is under investigation and must not be treated as the production Nile Tropical target.

## Current branch
`reconcile/live-supabase-20260927`

## Current PR
PR #2: Reconcile Flutter frontend with live Supabase backend.

## Do not do
- Do not create another Supabase project.
- Do not reset the production database.
- Do not blindly replay old migrations.
- Do not deploy payment Edge Functions without comparing them with production.
- Do not claim Airtel/card are operational without configured providers.
- Do not infer production state from GitHub alone.

## Latest contract audit
- Live migration history now includes the 2026-09-24 through 2026-09-27 reconciliation migrations; do not treat 016–024 as the complete live history.
- Live payment-initiate v29 still contains the obsolete `payments` table path for non-MTN methods. Branch code is reconciled to `payment_transactions` but has not been deployed.
- Live payment-status v22 was inspected. Branch code now requires a matching local MTN transaction and checks provider/method/amount/currency before changing payment state.
- Live payment-status previously jumped successful payment from `payment_pending` to `new_order`; branch now uses the valid `payment_confirmed` transition.
- Live track-order v7 currently has `verify_jwt=true`. Guest/public phone-verified tracking requires the branch deployment to explicitly use `--no-verify-jwt`.
- Flutter order/payment services previously fabricated state when Supabase was unconfigured. Branch now fails closed for checkout, tracking and payment initiation.
- Storage buckets and core POD/courier/staff policies have been inspected. Full Flutter-path authorization audit remains pending.
- GitHub workflow target and automatic database-push risks have been reconciled in branch; branch is not production-deployed.

## Next handoff
Supabase-connected session should continue verifying Auth provider configuration, full RLS authorization for every Flutter/admin path, exact deployed function versions after controlled deployment, and live end-to-end behavior.

GitHub-connected session should run Flutter analyze/tests/build and inspect the remaining admin/inventory/delivery frontend mappings before any merge or production deployment.


## 2026-09-27 continued audit handoff

The authorization/payment pass continued on reconcile/live-supabase-20260927.

New repository changes:
- Restored supabase/functions/payment-webhook/index.ts from the live contract with safer error handling and the correct order_status_history.note column.
- Narrowed the analytics Edge Function role gate to manager/finance/super_admin.
- Added repository-only lifecycle/RLS reconciliation migration 20260927_authorization_lifecycle_reconciliation.sql.
- No production RLS, migration, role assignment, or Edge Function deployment was performed.

Important live findings:
1. payment-webhook v17 is deployed but was absent from the branch source.
2. Live webhook uses an incorrect history column name (notes vs canonical note).
3. update_order_status transition matrix references payment_failed while its accepted status list omitted it.
4. Analytics gateway role allow-list was broader than the documented role matrix.
5. Broad is_staff() RLS remains a production finding; do not redefine the helper globally.

Next required gate:
Audit → Reconcile → Test → Review → Approve → Deploy → Verify

Deployment remains out of scope until non-production role-fixture testing and review of the repository-only RLS migration are complete.
