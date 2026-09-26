# Nile Tropical — AI Collaboration Start Here

**Read this file before making any change to this repository.**

Repository: `odoema/niletropical`  
Production backend authority: Supabase project `ououfhsswyqutcczdtnb`  
Production URL: `https://ououfhsswyqutcczdtnb.supabase.co`  
Primary reconciliation branch: `reconcile/live-supabase-20260927`  
Current reconciliation PR: #2

## Mission

Nile Tropical is a production Flutter/Flutter Web + Supabase commerce and operations platform.

Every AI contributor must use:

**Audit → Reconcile → Implement → Test → Review → Approve → Deploy → Verify**

Do not optimize for repository neatness at the expense of the live system.

## Source of truth

- **Supabase = what is actually live.**
- **GitHub = what is implemented/proposed.**

Never treat a migration, README, old conversation, another AI's statement, or a branch as proof of production state. Verify production facts directly.

## Production identity — critical

Production Supabase project:

`ououfhsswyqutcczdtnb`

`tyhqwngqxbcivfphgxck` must not be treated as production unless fresh live evidence explicitly proves that.

## Read first

Before substantial work, read:

1. `AI_START_HERE.md`
2. `AGENTS.md`
3. `docs/AI_HANDOFF.md`
4. `docs/backend-contract.md`
5. `docs/frontend-backend-map.md`
6. `docs/reconciliation-status.md`

If documentation conflicts with live Supabase, Supabase wins. Update the documentation after verification.

## Collaboration

Multiple AI systems may work on this repository. GitHub is the shared engineering state.

- `docs/AI_HANDOFF.md` = current cross-AI handoff.
- `docs/backend-contract.md` = verified production backend facts.
- `docs/reconciliation-status.md` = current project/evidence state.
- `docs/frontend-backend-map.md` = frontend/backend integration contract.

Do not create competing source-of-truth documents.

## Safety rules

Never:

- create another production Supabase project;
- reset/wipe/destructively rebuild production;
- blindly replay migrations against production;
- automatically run `supabase db push` against production;
- fabricate orders, stock, totals, payment states, tracking results, or production responses;
- trust client prices/totals over server/database values;
- reintroduce Flutterwave; it is legacy/reference-only;
- claim Airtel Money or cards are operational without real provider configuration/testing;
- expose passwords, service-role keys, tokens, private keys, or secrets.

Preserve guest checkout. Zero inventory is valid. Do not invent stock.

## Critical live contracts

- Payment table: `payment_transactions`.
- Order creation: inspect both live `create_order()` overloads before changing either.
- Delivery pricing is server-authoritative: UGX 2,500 + UGX 450/km.
- Pricing recommendation field: `suggested_retail_price`.
- Guest tracking: `track-order`, using order number + phone verification.
- Payment flow: `Flutter → payment-initiate → payment_transactions → MTN gateway → payment-status → orders → notifications`.
- Payment state transitions must follow the live order-status contract.

## Current state — 2026-09-27

- Production Supabase: LIVE VERIFIED.
- Core backend contract: LIVE VERIFIED.
- GitHub production target: reconciled on the reconciliation branch.
- Automatic production DB push: removed from the reconciliation branch.
- Payment-initiate/status fixes: in reconciliation branch, not yet deployed.
- Guest tracking deployment correction: in reconciliation branch, not yet deployed.
- Flutter analyze/tests/web build: pending.
- Full frontend Auth/RLS audit: pending.
- Real checkout/MTN/tracking/notification tests: pending.
- Production deployment: not approved.

## How to work

### 1. Audit
Search for stale or dangerous references including:

`tyhqwngqxbcivfphgxck`, `payments`, `recommended_price`, `current_price`, `proposed_price`, `customer_name`, `orders.customer_name`, `create_order`, `quote_delivery`, `track-order`, `payment_transactions`, `record_app_error`, `app_error_logs`, `supabase db push`.

Then inspect the relevant live Supabase contract.

### 2. Reconcile
Change only what is demonstrably inconsistent.

### 3. Implement
Make focused, production-safe changes. Preserve working behavior.

### 4. Test
Run appropriate static analysis, unit/widget tests, builds, and controlled integration tests.

### 5. Document
Update the shared handoff/status documents with evidence.

## Evidence vocabulary

Use these terms precisely:

- **LIVE VERIFIED** — directly confirmed in production Supabase.
- **REPOSITORY** — present in GitHub.
- **RECONCILED** — source changed to match verified live behavior.
- **TESTED** — behavior actually tested.
- **DEPLOYED** — confirmed in the live environment.
- **PENDING/UNVERIFIED** — evidence is missing.

Never upgrade a status without evidence.

## GitHub-connected AI

Primarily:

- audit Flutter/Edge Function source;
- compare source with the live backend contract;
- fix integration mismatches;
- run analyze/tests/build;
- inspect CI/deployment configuration;
- make focused commits;
- update shared documentation.

## Supabase-connected AI

Primarily:

- inspect live project `ououfhsswyqutcczdtnb`;
- verify tables/functions/RLS/Auth/Storage;
- inspect deployed Edge Functions;
- safely test SQL/RPC behavior;
- record verified facts in `docs/backend-contract.md`;
- avoid destructive changes.

## When another AI has changed code

Do not overwrite it automatically.

Inspect the commit, diff, shared documentation, live state where relevant, and test evidence. Preserve correct work and fix demonstrated problems.

## Deployment

Deployment is a separate phase:

**Audit → Reconcile → Implement → Test → Review → Approve → Deploy → Verify**

No AI session should silently skip these stages.

## Final rule

**Do not guess. Do not fabricate. Do not silently change production.**

When uncertain, record the uncertainty, gather evidence, and let the evidence determine the next action.
