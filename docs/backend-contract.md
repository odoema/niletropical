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
- RLS is enabled across the inspected core tables; order/payment/pricing/error/storage policies have been inspected, with full frontend-path authorization audit still pending.
- Canonical public tracking path is the `track-order` Edge Function.
- Payment records use `payment_transactions`; the deployed `payment-initiate` v29 was observed to still reference the obsolete `payments` table for non-MTN methods, so the branch fix is not yet deployed.
- Pricing recommendations use live fields including `variant_id` and `suggested_retail_price`.
- Distance-aware delivery uses UGX 2,500 + UGX 450/km, with the server authoritative for the final order quote.
- COD orders are created unpaid/in the new-order lifecycle; online-payment orders enter the payment-pending lifecycle. Successful MTN payment should transition `payment_pending` → `payment_confirmed`.

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
- exact production Edge Function versions versus repository code; **verified that payment-initiate v29 and payment-status v22 are not yet the branch-reconciled implementations**;
- final RLS policies for every Flutter/admin path;
- Auth provider configuration;
- Storage policy details; **core bucket visibility and POD/courier/staff policies verified**;
- complete frontend-to-RPC argument mapping;
- production GitHub Actions credentials and target values;
- end-to-end checkout, MTN payment, tracking and email notification.

`tyhqwngqxbcivfphgxck` is not the production target for this reconciliation unless independently re-established by live evidence.
## Audit findings requiring branch verification
- The deployed `track-order` v7 currently has `verify_jwt=true`, while the Flutter tracking path is intended for guest/public phone-verified tracking. The branch workflow now explicitly deploys it with `--no-verify-jwt`; this must be verified after deployment.
- The deployed `payment-status` implementation can reconcile an MTN gateway response without first proving a matching local `payment_transactions` row. The branch now requires the local transaction and checks provider/method/amount/currency before changing payment state.
- The branch payment-status lifecycle now uses `payment_confirmed` rather than jumping directly from `payment_pending` to `new_order`, matching the live status-transition contract.
- The live migration history now includes the 2026-09-24 through 2026-09-27 reconciliation migrations; earlier documentation claiming only migrations 016–024 is obsolete.
