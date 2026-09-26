# Nile Tropical — Frontend / Backend Map

Repository: `odoema/niletropical`
Backend authority: `ououfhsswyqutcczdtnb`

| Flutter area | Backend contract | State |
|---|---|---|
| Checkout | `create_order()` | RECONCILED |
| Delivery quote | `quote_delivery()` | RECONCILED |
| Tracking | `track-order` Edge Function | RECONCILED |
| MTN initiation | `payment-initiate` + `payment_transactions` | RECONCILED IN BRANCH |
| MTN status | `payment-status` + `payment_transactions` | RECONCILED IN BRANCH |
| Payment confirmation email | `notification-dispatch` | IMPLEMENTED / DEPLOYMENT PENDING |
| Pricing admin | `pricing_recommendations` + `apply_pricing_recommendation()` | RECONCILED IN BRANCH |
| App errors | `record_app_error()` / `app_error_logs` | RECONCILED |
| Inventory | products / variants / stock tables and RPCs | AUDIT PENDING |
| Admin orders | orders / order items / admin RPCs | AUDIT PENDING |
| Auth | Supabase Auth + RLS | AUDIT PENDING |
| Storage | Supabase Storage buckets/policies | AUDIT PENDING |

## Checkout contract
The frontend must not fabricate a successful production order when Supabase is unavailable.

The server remains authoritative for prices, stock, delivery fee and total.

## Delivery contract
Current reconciled model:
`delivery_fee = round(2500 + distance_km * 450)`

The route distance is road distance supplied by the routing layer; the server recalculates the authoritative quote.

## Payment contract
COD does not use the payment gateway.
MTN Mobile Money uses `payment_transactions` and the MTN gateway.
Airtel/card are explicitly not configured until their real providers are integrated.

## Tracking
The Flutter client should treat `track-order` as the canonical public tracking interface rather than duplicating tracking business logic locally.

## Audit rule
Every mapping must eventually be classified as LIVE VERIFIED, REPOSITORY, RECONCILED, TESTED, DEPLOYED, or UNVERIFIED.