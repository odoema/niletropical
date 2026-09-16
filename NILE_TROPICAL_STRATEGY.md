# Nile Tropical — Continuation Strategy (Handoff Document)

**Last updated:** 2026-09-16  
**Purpose:** Self-contained strategy so any AI or developer can continue the work without prior conversation context.

---

## 1. Project Summary

**Product:** Nile Tropical Uganda — Digital Commerce & Operations Platform  
**Owner:** Hon. Dr. Betty Udongo Pacutho / Nile Tropical Industries Ltd  
**Stack:**
- **Frontend:** Flutter (mobile-first, also web/Windows)
- **Backend:** Supabase (PostgreSQL + Auth + Storage + RLS + Edge Functions)
- **Payments:** MTN MoMo, Airtel Money, Card, Cash on Delivery (COD)
- **State / Routing:** Riverpod + GoRouter

**Primary goal of current work:**  
Build and harden the **Flutter frontend** so it fully utilises the already-existing, production-capable Supabase backend.  
Do **not** redesign or rewrite the backend schema unless a clear bug is found.

---

## 2. Current Live Backend

- **Project:** `niletropical`  
- **Ref:** `ououfhsswyqutcczdtnb`  
- **URL pattern:** `https://ououfhsswyqutcczdtnb.supabase.co`

The backend already contains:
- Full catalogue (products, variants, images, videos, categories)
- Inventory (warehouses, warehouse_stock, batches, stock_movements, reservations)
- Customers + addresses
- Orders + order_items + status history
- Payments + webhooks + COD collections
- Delivery zones, partners, couriers, shipments, delivery_events, proof_of_delivery
- Promotions, coupons, coupon_redemptions
- CMS (banners, pages, FAQs, testimonials, videos)
- Notifications (templates + logs)
- Audit logs
- Role system (`app_role` enum + `user_roles` + RLS helpers `has_role`, `is_staff`, `delivery_ops_authorized`)
- Key RPCs: `create_order`, `track_order`, `admin_upsert_product`, `record_stock_movement`, `submit_proof_of_delivery`, `update_order_status`, `update_shipment_status`, `validate_coupon`, etc.

**Rule:** Treat the live database as the source of truth. Prefer reading live schema / RPCs over old migration files when they conflict.

---

## 3. Flutter Project Location & Structure

**Typical Windows path (user machine):**
```
C:\Users\odoem\Downloads\Susan\Betty\now\nile_tropical
```

**Key folders:**
```
lib/
  core/               # theme, config, router, widgets
  features/           # customer-facing screens
  admin/              # admin / staff screens
  shared/             # models, providers, services
  data/repositories/  # (if present)
supabase/             # migrations + local function skeletons
assets/
test/
```

**Important config:**
- `lib/core/config/env.dart` — reads `SUPABASE_URL` + `SUPABASE_ANON_KEY` via `--dart-define`
- Never put service-role keys in the Flutter app

**Run commands (Windows):**
```bat
cd /d "C:\Users\odoem\Downloads\Susan\Betty\now\nile_tropical"
flutter pub get
flutter analyze
flutter run -d chrome --dart-define=APP_ENV=development
```

For real backend:
```bat
flutter run -d chrome ^
  --dart-define=SUPABASE_URL=https://ououfhsswyqutcczdtnb.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<anon-key> ^
  --dart-define=APP_ENV=development
```

---

## 4. Architecture Rules (Do Not Break)

1. **Backend is authoritative**
   - Prices, stock, totals, order numbers → calculated in RPCs (`create_order`, etc.)
   - Frontend must never write `orders.payment_status = 'paid'` directly
   - Frontend must never decrement stock client-side

2. **Auth & roles**
   - Staff access controlled by `user_roles` + RLS + helpers (`has_role`, `is_staff`)
   - Admin routes must remain guarded
   - Courier only sees shipments assigned to their `couriers` row

3. **Payments**
   - Live Edge Functions already exist: `payment-initiate`, `payment-status`, `payment-webhook`
   - **Do NOT** deploy the local skeletons in `supabase/functions/payment-*` over the live versions
   - Flutter only calls initiate + status; webhooks stay server-side

4. **Storage**
   - Public: `product-images`, `product-videos`, `banners`
   - Private: `proof-of-delivery`, `testimonial-media`
   - Use `getPublicUrl` for public buckets, `createSignedUrl` for private

5. **Idempotency**
   - Order creation uses `p_idempotency_key` — always send a stable UUID per cart attempt

---

## 5. Priority Work Queue (from GAPS_TRACKER.md)

| Priority | Gap | Backend ready? | Effort | Status | Notes |
|----------|-----|----------------|--------|--------|-------|
| 1 | Coupon at checkout | Yes | Small | **Done** | Already shipped |
| 2 | Admin **Customers** screen | Yes | Small–Medium | Not started | Highest remaining ops value |
| 3 | COD cash reconciliation UI | Yes (`cod_collections`) | Medium | Not started | Critical if COD is used |
| 4 | Proof-of-delivery **photo capture** | Partial | Medium | Not started | Bucket exists; RPC accepts path |
| 5 | Pricing recommendation approval UI | Yes | Medium | Not started | |
| 6 | Notification templates/logs admin | Yes | Medium | Not started | |
| 7 | Audit log viewer | Yes | Small–Medium | Not started | |
| 8 | Admin Settings / feature flags | Partial | Medium | Not started | |

**Recommended next work order:**
1. Admin Customers screen (#2)
2. COD reconciliation (#3)
3. POD photo capture (#4)
4. Then 5 → 8 as needed

---

## 6. How to Continue (Instructions for Next AI)

### When starting a new session
1. Read this file first.
2. Read `GAPS_TRACKER.md` and `STATUS.md`.
3. Confirm current Flutter tree with `dir` / `tree lib`.
4. Ask the user which gap (or bug) to attack next if not already specified.
5. Prefer **minimal, targeted changes** over large rewrites.
6. After any meaningful change, update `GAPS_TRACKER.md` status and add a short log entry.

### Coding conventions already in use
- Riverpod for state
- GoRouter for navigation
- Nile design system (`NileColors`, `Nile*` widgets) — prefer these over raw Material
- Services live under `lib/shared/services/`
- Models under `lib/shared/models/`
- Admin screens under `lib/admin/` (or equivalent feature folder)

### Safe change pattern
1. Locate the existing service / screen for the feature.
2. Extend it; do not create parallel duplicate services.
3. Call existing RPCs with the exact parameter names the live backend expects.
4. Keep RLS and role checks intact.
5. Test the happy path + one failure path.

### What to avoid
- Do not rewrite the entire schema.
- Do not replace live payment Edge Functions.
- Do not hard-code Supabase keys.
- Do not invent new table/column names that contradict the live database.
- Do not remove working customer flows while adding admin features.

---

## 7. Key Backend Contracts the Frontend Must Honour

### create_order (authoritative)
- Accepts cart items, address, zone, payment method, optional coupon
- Server recalculates prices, delivery fee, discount, total
- Creates order + items + status history + stock reservation
- Returns order number / id

### track_order
- Public: order_number + phone → status + history + items

### submit_proof_of_delivery
- Expects shipment id + optional OTP/signature + **photo storage path** + payment collected (for COD)
- Updates shipment + order status + COD collection when applicable

### Roles
```text
super_admin | manager | sales_staff | inventory_officer | finance | content_manager | courier
```

### Storage paths (examples)
- Product images → `product-images/...`
- POD photos → `proof-of-delivery/photos/...`
- POD signatures → `proof-of-delivery/signatures/...`

---

## 8. Useful Reference Files in the Repo

| File | Purpose |
|------|---------|
| `GAPS_TRACKER.md` | Living list of remaining frontend gaps |
| `STATUS.md` | High-level current status |
| `README.md` | Overview + run instructions |
| `AUDIT.md` | Historical correctness audit (important background) |
| `RELEASE_BASELINE.md` | What is considered stable |
| `MERGE.md` | Rules about not mixing old migration sets |
| `lib/core/config/env.dart` | Environment / dart-define handling |
| `lib/shared/services/` | Canonical services (order, delivery, etc.) |

---

## 9. Immediate Recommended Next Action

**Build the Admin Customers screen (Gap #2).**

Scope suggestion:
- List customers (search by name / phone / email)
- Show status, order count, last order date
- Drill-down to customer detail: addresses + order history
- Staff-only (reuse existing admin shell + role guard)
- Read from `customers`, `customer_addresses`, `orders` tables (RLS already allows staff)

After that screen is solid, move to COD reconciliation.

---

## 10. Communication Style for Future AIs

- Be concrete and file-oriented.
- Prefer patches / new screens over abstract advice.
- Always state which gap or bug is being closed.
- Update the gap tracker when a gap is finished.
- If the live backend differs from old migration files, trust the live backend and note the discrepancy.

---

**End of strategy document.**  
Any AI receiving this file + the current Flutter tree + access to the live Supabase project has enough context to continue productively.
