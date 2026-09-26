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

## Next handoff
Supabase-connected session should verify exact live create_order overloads, quote_delivery behavior, pricing RPC/table contract, payment_transactions schema, deployed payment/tracking/notification function versions, Auth/RLS, Storage policies, and migration history versus repository migrations.

GitHub-connected session should then reconcile remaining differences and run the complete Flutter validation suite.