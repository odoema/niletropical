# Nile Tropical — Audit report (Fixed4, 2026-09-11 pass 2)

Second-pass audit against `nile_tropical_fixed3.zip`, incorporating the
issues flagged by ChatGPT's Fixed3 audit and everything ChatGPT missed.

## The single biggest problem in Fixed3 (that ChatGPT missed)

**Every SQL migration fix from the earlier Fixed bundle was reverted.**
Fixed3 was rebuilt from the original lineage, so migrations 016–022 came
back byte-for-byte broken:

- `create_order` (016) writes to `delivery_zones.fee` — column is `delivery_fee`
- `create_order` writes to `order_items(product_variant_id, product_name)` — columns are `variant_id` + `*_snapshot`
- `create_order` writes to `order_status_history(status, note)` — columns are `to_status`, `notes`
- `record_stock_movement` (017) writes to `stock_movements(quantity_delta, reason, reference_id, note)` — none exist
- `track_order` (018) reads the same wrong `order_status_history` columns
- `admin_upsert_product` (019) references `products.description`, `product_images.url/is_primary` — none exist
- `admin_create_delivery_zone` (019) references `delivery_zones.fee` and `delivery_zones.districts` — neither exists
- `admin_create_courier` (019) references `couriers.delivery_partner_id` — doesn't exist
- `submit_proof_of_delivery` (020) writes POD fields to `shipments` — they belong on the separate `proof_of_delivery` table
- `create_shipment` (020) writes `warehouse_id` to `shipments` — doesn't exist
- Migrations 021, 022 same broken versions

Net effect: `supabase db push` succeeded but every RPC call from the app
would have failed at runtime with "column does not exist". Every good
Dart improvement in Fixed3 was calling into a broken database.

**All of this has been restored to the correct versions in Fixed4.**

## New in Fixed3 — kept (good work)

- `AuthService` with real Supabase Auth (`signInWithPassword`, `rolesForCurrentUser`, `canAccessAdmin`, `canAccessCourier`)
- `GoRouter redirect:` guard on `/admin/*` and `/courier/*`
- `AdminLoginScreen` that actually authenticates and routes by role
- `PaymentMethods` constants + `normalize()` — cleanly maps legacy aliases (`mtn_direct` → `mtn_momo`)
- Reports screen queries orders live (no more `salesToday = 185000`)
- `AccountOrdersScreen` and `AccountAddressesScreen` are real screens (with bugs, now fixed — see below)
- `CourierDashboardScreen` queries shipments (with a security bug, now fixed)
- Product form calls `admin_upsert_product` (with missing fields, now expanded)
- POD screen calls `submit_proof_of_delivery` (with wrong param mapping, now fixed)
- Order detail calls `set_order_status` (which was broken in 024, now rewritten)
- `_DO_NOT_DEPLOY/README.md` on the local Edge Function copies — important safeguard
- Logo asset added
- Migration `023_payments_reference.sql` — legitimate schema addition, kept

## New in Fixed3 — bugs, now fixed in Fixed4

1. **`AccountAddressesScreen`** — fabricated `'0000000000'` phone would crash on the second user (unique constraint on `customers.phone`), and never set `customers.auth_user_id`, so RLS on `customer_addresses` blocked reads after insert. Rewritten to look up customers by `auth_user_id`, require a real phone at first-address entry via form validation, and set `auth_user_id` on the new customer row.
2. **`AccountOrdersScreen`** — filtered by `customer_email`; also `create_order` never populated `orders.customer_id`. Rewritten to resolve the customer via `auth_user_id`, filter orders by `customer_id`, and fall back to email only for orders placed before signup. And `create_order` now sets `orders.customer_id` from `auth.uid()` when a matching customers row exists.
3. **`CourierDashboardScreen`** — read all non-delivered shipments and relied on RLS. Rewritten to resolve the courier via `auth.uid() → couriers.auth_user_id → couriers.id` and filter explicitly.
4. **`ProofOfDeliveryScreen`** — stuffed the OTP into `p_photo_url` as `'otp:${code}'`. The rewritten RPC has separate `p_photo_storage_path` and `p_otp_or_signature` params; POD screen now sends the OTP to the right slot.
5. **`ProductFormScreen`** — sent `full_description` as `description`, and dropped `benefits`, `how_to_use`, `cost_price`, `compare_at_price`, `reorder_level`, `is_bestseller`, `is_new`, `is_promotional`, and the variant name. All propagated now.
6. **`DeliveryService.createZone`/`createCourier`** — used old param names (`p_fee`, `p_districts`, `p_partner_id`) that don't match the rewritten 019. Updated to `p_delivery_fee`, `p_estimated_days`, `p_notes`, `p_vehicle_type`, `p_operating_area`, `p_commission_rate`.
7. **`024_set_order_status.sql`** — was writing to the wrong `order_status_history` columns AND duplicating the transition trigger from 013 AND had no role check AND redefined `admin_create_delivery_zone` as an ambiguous overload. Rewritten to: cast the status text to the enum (letting the trigger from 013 do the transition validation and history logging), require sales/manager/super_admin, optionally attach a per-call note to the row the trigger just wrote, and drop the ambiguous overload.

## Migration 023 is left alone (legitimate)

`023_payments_reference.sql` adds `payments.provider` and `payments.provider_reference` with a unique index. That's a pragmatic dual-truth choice (provider tracking exists on `payment_transactions` too, but having it directly on `payments` makes `payment-status` polling trivial). Kept as-is.

## Not fixed in this pass (larger scope — flag me for the next round)

- Real image capture + Supabase Storage upload for POD photo and product images
- Full CMS management screens for banners/pages/FAQs/testimonials/videos/promotions
- Product image gallery on the storefront
- Complete multi-variant product editor UI
- Notification providers (SMS/WhatsApp/Email/Push)
- Simplifying the brand palette to Nile blue + white + neutrals (remove `secondary`, `accent` browns/golds)
- E2E tests against a live Supabase project

These are all real gaps but they're feature work, not correctness bugs.

## Message for whoever builds Fixed5

The SQL migration fixes are the load-bearing floor of the whole app. If you rebuild from the original zip you will throw them away and every RPC call will fail again. Merge from Fixed4's `supabase/migrations/` folder verbatim, or diff before you replace anything.
