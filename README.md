# Nile Tropical Uganda
**Digital Commerce & Operations Platform**

© Hon. Dr. Betty Udongo Pacutho

See **STATUS.md** for the live implementation status (the P3–P10 checkboxes below are historical).

## Overview

Production-oriented mobile-first platform for Nile Tropical Industries Ltd covering:

- Customer e-commerce (browse, buy, pay, track)
- Inventory & stock movements
- Order processing & dispatch
- Delivery management (Kampala + Outside)
- Reporting
- Role-ready admin

### Core Principles
- Three-click path to purchase
- Mobile-first Flutter
- MTN MoMo / Airtel Money / Card / Cash on Delivery
- Real inventory & batch/expiry awareness
- Full order lifecycle

## Tech Stack
- **Frontend**: Flutter (responsive)
- **Backend**: Supabase (PostgreSQL + Auth + Storage + RLS)
- **Payments**: MTN, Airtel, Cards + COD

## Payment Integration Documentation

The production MTN Mobile Money integration is documented in **[docs/MTN_MOMO_INTEGRATION.md](docs/MTN_MOMO_INTEGRATION.md)**.

It records the server-side Request-to-Pay flow, payment reconciliation, order-state transition, duplicate-email protection, tracking integration, required environment variables, and deployment architecture.

## Project Structure

```
lib/
├── core/           # Theme, constants, router
├── features/       # Customer screens (home, shop, product, cart, checkout, tracking)
├── shared/         # Models, providers, services, widgets
└── admin/          # Admin hub, orders, inventory, products, delivery, reports
```

## Key Routes

**Customer**
- `/` Home
- `/shop` Shop
- `/product/:slug` Product Detail
- `/cart` Cart
- `/checkout` Checkout
- `/confirmation` Order Confirmation
- `/track` / `/track/:orderNumber` Tracking

**Admin**
- `/admin` Admin Hub
- `/admin/orders` Order List
- `/admin/orders/:id` Order Detail + Dispatch
- `/admin/orders/:id/pod` Proof of Delivery
- `/admin/inventory` Inventory Dashboard
- `/admin/inventory/adjust` Stock Adjustment
- `/admin/products` Product List
- `/admin/products/new` Add Product
- `/admin/delivery` Delivery Dashboard
- `/admin/reports` Reports

## Phases (status as of the codebase audit — see AUDIT.md)
- [x] P0 — Repo cleanup: env config, .gitignore, mock data separated into `supabase/seed/dev_seed.sql`, test scaffold started
- [x] P1 — Supabase schema: 14 migrations covering catalog, inventory, orders, payments, delivery, content, promotions, notifications, audit + RLS (see `supabase/migrations/`)
- [ ] P2 — Real product catalogue wired end-to-end (query code exists in `supabase_service.dart`, untested against a live project)
- [ ] P3 — Production checkout with server-side price validation
- [ ] P4 — Payment gateway integration + webhook verification (no gateway chosen yet — MTN MoMo/Airtel direct vs. Pesapal/Xyle aggregator)
- [ ] P5 — Real order creation wired to `orders`/`order_items`/`order_status_history` (atomic stock RPC `adjust_stock()` is ready and already wired into `inventory_service.dart`)
- [ ] P6 — Delivery zones/partners/couriers wired to DB (currently 100% mock, schema now exists)
- [ ] P7 — Notification provider integration (SMS/WhatsApp/Email — schema + message templates exist, no provider wired)
- [ ] P8 — CMS, testimonials, promotional popup
- [ ] P9 — Reporting, reconciliation, audit log writes
- [ ] P10 — Auth guard on `/admin/*` routes (currently unauthenticated — **do not deploy before this**), Storage buckets
- [ ] P11 — E2E testing (unit test scaffold started in `test/unit/`; no Flutter SDK was available in the audit environment to actually run `flutter test` — run it locally before trusting these)
- [ ] P12 — Production deployment

## What Remains for Production Launch

1. **Create a real Supabase project** and run `supabase/migrations/*.sql` in order (or `supabase db push`)
2. Provide real Supabase URL + Anon Key via `--dart-define` (see `lib/core/config/env.dart`) — never hard-code them
3. Choose and connect a payment gateway (MTN MoMo / Airtel Money direct vs. Pesapal/Xyle aggregator) + webhook verification
4. Wire `order_service.dart`, `delivery_service.dart` to real inserts (schema is ready; client code is not yet wired for orders/delivery)
5. Implement image/video upload to Supabase Storage buckets (not yet created)
6. **Add a login screen and wire Supabase Auth + role checks to guard `/admin/*` routes** — currently anyone can reach admin screens
7. Wire notification providers (SMS / WhatsApp / Email) behind `notification_service.dart`
8. Run `flutter test` locally and expand coverage beyond the current cart-only scaffold
9. Domain + SSL + deployment

## Getting Started

```bash
cd nile_tropical
flutter pub get

# Local development (no Supabase project needed yet — uses dev seed/mock fallback)
flutter run

# Once a Supabase project exists, apply the schema:
supabase link --project-ref <your-project-ref>
supabase db push
psql "$DATABASE_URL" -f supabase/seed/dev_seed.sql   # optional, dev only

# Run against real Supabase:
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxx \
  --dart-define=APP_ENV=development
```

## Deployment checklist

Use this before a production or staging release. Do **not** treat a zip as deployed.

### 1. Supabase project
- [ ] Project ref is the live one (`uxjmddlmkhqwvgimxiny` or the intended env)
- [ ] `SUPABASE_URL` and **anon** key only in Flutter `--dart-define` / CI secrets
- [ ] Service role key is **never** in the app binary
- [ ] Auth email provider enabled for staff logins

### 2. Schema and RPCs
- [ ] Migrations applied in order `001` → `025` **or** confirmed already present on live
- [ ] Prefer live schema if it has already drifted; do not blindly `db push` older zip SQL
- [ ] Confirm these RPCs exist and match Flutter param names:
  - `create_order`
  - `track_order`
  - `admin_upsert_product`
  - `admin_create_delivery_zone` (`p_delivery_fee`, not `p_fee`)
  - `admin_create_courier`
  - `set_order_status` / live equivalent
  - `update_shipment_status`
  - `submit_proof_of_delivery` (`p_photo_storage_path`, `p_otp_or_signature`)
- [ ] RLS policies reviewed for `orders`, `shipments`, `customers`, `storage.objects`

### 3. Storage
- [ ] Run `supabase/migrations/025_storage.sql` only after checking Dashboard bucket ids
- [ ] Buckets: `product-images` (public), `cms` (public), `pod` (**private**)
- [ ] Test staff upload to `product-images` and courier upload to `pod`
- [ ] Confirm storefront uses `getPublicUrl` and POD uses `createSignedUrl`

### 4. Edge Functions — do not clobber live
- [ ] Live functions remain: `payment-initiate` (v13), `payment-status` (v5/v6), `payment-webhook` (v10/v11)
- [ ] **Do not** `supabase functions deploy` from this repo’s `payment-*` skeletons
- [ ] Function secrets set in Dashboard (provider keys), not in git
- [ ] Webhook URL given to MTN/Airtel/card; not exposed as an app route
- [ ] Flutter only calls `payment-initiate` and `payment-status`

### 5. Flutter build
- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `APP_ENV=production` (or `staging`) so mock catalogue cannot ship
- [ ] `Env.assertConfiguredOrThrow()` passes with real URL + anon key
- [ ] `flutter build apk` and/or `flutter build web`

### 6. Roles and smoke tests
- [ ] Staff users have `profiles` + `user_roles` (or `profiles.role`) matching live enum
- [ ] Customer cannot open `/admin`
- [ ] Courier sees only `shipments.courier_id` for their `couriers.auth_user_id`
- [ ] Guest checkout → `create_order` → pay pending → poll status
- [ ] COD path does not call the gateway
- [ ] Track by order number + phone
- [ ] Admin product save + order status change write history
- [ ] POD rejects OTP stuffed into the photo field

### 7. Content and ops
- [ ] At least one delivery zone in `delivery_zones`
- [ ] Featured / bestseller / new flags set on real products
- [ ] Public `/faq` and `/pages/about` have published rows
- [ ] Logo at `assets/images/logo.png` included in the build

### 8. After deploy
- [ ] Payment test on a small live order
- [ ] Webhook events appear in `payment_transactions` / `payment_webhook_events`
- [ ] No client write to `orders.payment_status = paid`
- [ ] Error reporting / logs on Edge Functions checked

## Copyright
© Hon. Dr. Betty Udongo Pacutho  
All rights reserved.


## Native permissions (image_picker)

This zip is Dart-only. After `flutter create .`:

**iOS** `ios/Runner/Info.plist`
- `NSCameraUsageDescription` — Take a photo as proof of delivery.
- `NSPhotoLibraryUsageDescription` — Choose a product image.

**Android** `android/app/src/main/AndroidManifest.xml`
- `android.permission.CAMERA` for courier POD.

Then `flutter pub get` so `image_picker` resolves.


## Run on Windows / Chrome

This repo ships Dart sources only. Generate platform folders once:

```bat
flutter create . --platforms=windows,web
flutter run -d chrome
```

Do not put `#` comments on the same line in cmd.exe.
