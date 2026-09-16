# Nile Tropical — Full delivery (P2 → P14 scope)

## Completed in this package

### P2 — Design system ✅
- Tokens: NileColors (#233E85 primary), spacing, radius, typography (Poppins)
- 19 Nile* widgets + barrel + design-system showcase
- `google_fonts` dependency

### P3 — App shell + routing ✅
- `CustomerShell`, `AdminShell`, `CourierShell` + `ResponsiveScaffold`
- Full GoRouter with ShellRoutes covering customer / admin / courier
- New routes: account, addresses, orders, payment, courier, CMS, design-system, admin login

### P4–P7 — Customer surfaces (foundations) ✅
- Account hub + orders + addresses placeholders
- Tracking screen rewritten against `track_order` RPC (BUG-003)
- Payment page (method select → initiate skeleton)
- Product card restyled to Nile tokens
- OrderService rewritten for idempotent `create_order` v2

### P8–P11 — Admin / ops foundations ✅
- Admin dashboard KPI shell + quick actions
- CMS dashboard (banners, pages, FAQs, testimonials, videos, promotions)
- Admin login screen
- Courier dashboard + shipment detail (POD / COD actions)

### Backend migrations 015–022 ✅
| File | Purpose |
|------|---------|
| 015_warehouses.sql | warehouses, warehouse_stock, stock_reservations |
| 016_create_order_v2.sql | idempotent create_order + order_number_seq |
| 017_stock_v2.sql | warehouse-aware record_stock_movement |
| 018_track_order.sql | public track_order(order_number, phone) |
| 019_admin_rpcs.sql | admin_upsert_product, zone & courier helpers |
| 020_shipment_rpcs.sql | create/assign/status/POD |
| 021_payment_providers.sql | drop flutterwave; mtn/airtel/card/cash |
| 022_roles.sql | customer, inventory_officer, manager, admin, super_admin, courier |

### Edge Functions (skeletons) ✅
- `payment-initiate`
- `payment-status`
- Flutter `PaymentService` calling them (mock when unconfigured)

### Compatibility
- `typedef AppColors = NileColors` so existing screens keep compiling while they are migrated.

## Remaining polish (explicit)
- Wire live aggregates into admin dashboard KPIs (needs Supabase project)
- Full restyle of every pre-P2 screen to Nile* components (incremental)
- Real MTN/Airtel credentials in Edge Functions
- E2E tests against a live Supabase instance
- Production env files & CI

## How to run
```bash
cd nile_tropical
flutter pub get
flutter run \
  --dart-define=APP_ENV=development
# With Supabase:
#   --dart-define=SUPABASE_URL=... \
#   --dart-define=SUPABASE_ANON_KEY=...
```

Apply migrations in order 001→022 on your Supabase project, then deploy Edge Functions.

## Execution order status
1 Audit ✅  2 Design system ✅  3 Shell ✅  4 Routing ✅  
5–8 Customer foundations ✅  9–11 Orders/payments/tracking ✅  
12–15 Account/courier/CMS shells ✅  
16–22 Backend RPCs & roles ✅  
Responsive scaffold ✅  

Final E2E against live backend is the only remaining production gate.

## Update — restyle pass (continued)

### Customer screens restyled to Nile DS
- Home (hero, featured grid, quick chips)
- Shop (search, sort, grid)
- Product detail (slug provider, variants, add-to-cart) — BUG-001
- Cart (line items, qty, checkout CTA)
- Checkout (zones, payment methods, idempotent create_order)
- Order confirmation

### Admin
- Order list with status filters + Supabase query path
- Order detail fetch-by-id + status actions — BUG-002

### Fixes
- OrderService cart item uses `variant.id` (was broken variantId)
- productBySlugProvider for real/mock product resolution

### Tests
- cart_test.dart expanded
- theme_test.dart (primary + status colours + ThemeData)
