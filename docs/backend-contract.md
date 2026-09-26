# Nile Tropical — Live Backend Contract

Authority: live Supabase project `ououfhsswyqutcczdtnb`
Repository: `odoema/niletropical`
Last coordination update: 2026-09-27

## Authority rule
Supabase is authoritative for production state. GitHub records implementation and intended deployment state.

## Verified live contract
- Production project: `ououfhsswyqutcczdtnb`.
- Database is operational and contains live Nile Tropical commerce data.
- Core tables include orders, order items, products, product variants, product images, customers, notification logs/templates, stock movements, warehouse stock, delivery/payment-related tables and website media.
- `app_error_logs` and `record_app_error()` have been reconciled against the live production role enum.
- `generate_order_number()` is operational.
- Live RPC contract includes two `create_order()` overloads, `quote_delivery()`, `apply_pricing_recommendation()`, and `record_app_error()`.
- RLS is enabled across the inspected core tables.
- Canonical public tracking path is the `track-order` Edge Function.
- Payment records use `payment_transactions`; the obsolete `payments` table must not be assumed to exist.
- Pricing recommendations use live fields including `variant_id` and `suggested_retail_price`.
- Distance-aware delivery uses UGX 2,500 + UGX 450/km, with the server authoritative for the final order quote.
- COD orders are created unpaid/in the new-order lifecycle; online-payment orders enter the payment-pending lifecycle.

## Edge Functions
- `track-order`
- `notification-dispatch`
- `payment-initiate`
- `payment-status`
- `analytics-dashboard`

Before deploying a function, compare repository code with the currently deployed production version.

## Payment contract
Flutter -> payment-initiate -> payment_transactions -> MTN gateway -> payment-status -> orders.payment_status -> notification-dispatch for email on successful transition.

Airtel Money and card must not be reported as successful until their real providers are configured.

## Migration rule
Do not blindly execute all repository migrations against production merely because they are absent from migration history. Reconcile the live schema first and apply only controlled, verified changes.

## Pending verification
- exact production Edge Function versions versus repository code;
- final RLS policies for every Flutter/admin path;
- Auth provider configuration;
- Storage policy details;
- complete frontend-to-RPC argument mapping;
- production GitHub Actions credentials and target values;
- end-to-end checkout, MTN payment, tracking and email notification.

`tyhqwngqxbcivfphgxck` is not the production target for this reconciliation unless independently re-established by live evidence.