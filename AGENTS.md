# Nile Tropical — AI Agent Instructions

This repository may be edited by multiple AI systems, including ChatGPT, coding agents, GitHub-connected agents, and Supabase-connected agents.

## First instruction

Before meaningful work, read:

- `AI_START_HERE.md`
- `docs/AI_HANDOFF.md`
- `docs/backend-contract.md`
- `docs/frontend-backend-map.md`
- `docs/reconciliation-status.md`

## Production authority

**Supabase project `ououfhsswyqutcczdtnb` is the production authority.**

`tyhqwngqxbcivfphgxck` is not production for this reconciliation unless fresh live evidence proves otherwise.

## Engineering method

Always follow:

**Audit → Reconcile → Implement → Test → Review → Approve → Deploy → Verify**

Supabase tells you what is live. GitHub tells you what is implemented.

## Hard safety rules

Never:

- create a replacement production Supabase project;
- reset/wipe production;
- blindly replay migrations;
- automatically run `supabase db push` against production;
- fabricate production data or payment state;
- trust client totals/prices over server/database values;
- reintroduce Flutterwave;
- claim an unconfigured payment provider works;
- expose secrets.

Do not deploy simply because code compiles. Production changes require evidence and controlled approval.

## Critical contracts

- Payment table: `payment_transactions`.
- Order creation: inspect both live `create_order()` overloads before changing either.
- Delivery pricing: server-authoritative, currently UGX 2,500 + UGX 450/km.
- Pricing recommendation field: `suggested_retail_price`.
- Guest tracking: `track-order`, verified by order number + phone.
- Payment lifecycle must follow the live order-status contract.

## Shared collaboration

Use `docs/AI_HANDOFF.md` for cross-agent coordination.

Use `docs/backend-contract.md` for facts verified against production.

Use `docs/reconciliation-status.md` for project status.

Do not create a competing source-of-truth document.

## Before committing

Check for stale references to:

`tyhqwngqxbcivfphgxck`, `payments`, `recommended_price`, `customer_name`, `supabase db push`

and verify that any remaining occurrence is intentional.

Update shared documentation when your change materially affects the backend/frontend contract.
