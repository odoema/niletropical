# Nile Tropical — Screen / Action / Authorization Matrix

Date: 2026-09-27
Branch: `reconcile/live-supabase-20260927`
Production target: `ououfhsswyqutcczdtnb`
Status: REPOSITORY — reconciliation evidence; NOT a production authorization change.

## Authorization rules

- Database authorization is authoritative; Flutter route visibility is not a security boundary.
- Function-level authorization is preferred for privileged mutations.
- Guest commerce paths must remain available where intentionally designed.
- Do not broaden a role merely to make a screen work.
- Do not mutate production role assignments during testing.

## Confirmed operational matrix

| Area | Screen / action | Backend contract | Required role / caller | Live state |
|---|---|---|---|---|
| Orders | List/read orders | `orders` SELECT | super_admin / manager / sales_staff / finance per reconciled policy target | LIVE policy currently includes broad `is_staff()`; REPAIR pending |
| Orders | View items/history | `order_items`, `order_status_history` | same operational read boundary | LIVE broad policy; REPAIR pending |
| Orders | Change order status | `update_order_status(order_id,new_status,note)` | super_admin / manager / sales_staff | LIVE function authorization |
| Orders | Payment failure transition | `update_order_status` | super_admin / manager / sales_staff | REPAIR pending: transition matrix includes `payment_failed`, accepted list mismatch |
| Checkout | Create order | `create_order(...)` | guest or authenticated customer | LIVE VERIFIED; SECURITY DEFINER intentionally callable |
| Checkout | Delivery quote | `quote_delivery(zone,distance)` | guest or authenticated customer | LIVE VERIFIED; SECURITY DEFINER intentionally callable |
| Tracking | Guest order tracking | `track_order(order_number,phone)` / track-order Edge Function | guest or authenticated customer | LIVE RPC callable; Edge Function JWT currently enabled |
| Inventory | Stock adjustment | `record_stock_movement(...)` | super_admin / manager / inventory_officer | LIVE function authorization |
| Inventory | Stock read | `warehouse_stock`, `stock_movements`, `stock_reservations` | inventory operations + approved management roles | LIVE broad policy; REPAIR pending |
| Products | Create/update product | `admin_upsert_product(...)` | super_admin / manager / inventory_officer | LIVE function authorization |
| Products | Main image replacement | `admin_replace_product_main_image(...)` | privileged authenticated admin | REPOSITORY hardening removes anon; NOT DEPLOYED |
| Pricing | Approve recommendation | `apply_pricing_recommendation(id)` | manager / finance / super_admin | REPOSITORY hardening removes anon; NOT DEPLOYED |
| Delivery | Create zone | `admin_create_delivery_zone(...)` | super_admin / manager / sales_staff / inventory_officer via delivery_ops_authorized | LIVE function authorization |
| Delivery | Create courier | `admin_create_courier(...)` | delivery operations roles | LIVE function authorization |
| Delivery | Create shipment | `create_shipment(...)` | delivery operations roles | LIVE function authorization |
| Delivery | Assign shipment | `assign_shipment(...)` | delivery operations roles | LIVE function authorization |
| Delivery | Update shipment | `update_shipment_status(...)` | authenticated function contract; exact screen-role minimum requires final review | LIVE function authorization |
| Delivery | Proof of delivery | `submit_proof_of_delivery(...)` | delivery operations OR assigned active courier | LIVE function authorization |
| Customers | Customer management | `customers`, `customer_addresses` | super_admin / manager / sales_staff target | LIVE broad policy; REPAIR pending |
| Customers | Link current user | `link_current_user_customer()` | authenticated user | REPOSITORY hardening removes anon; NOT DEPLOYED |
| COD / Finance | COD reconciliation | `cod_collections` | finance / manager / super_admin | LIVE policy/function contract; final screen audit pending |
| Payments | Payment transactions | `payment_transactions` | finance / manager / super_admin for staff reads | LIVE policy contract |
| Payments | Webhook events | `payment_webhook_events` | finance / manager / super_admin for staff reads | LIVE policy contract |
| Analytics | Dashboard | `analytics-dashboard` Edge Function | super_admin / manager / finance target | REPOSITORY source narrowed; live v5 still broader until deployment |
| Errors | Error log read/update | `app_error_logs` | manager / finance / super_admin | LIVE VERIFIED |
| Notifications | Notification log read | `notification_logs` | manager / finance / super_admin target | LIVE policy contract |
| Audit | Audit log read | `audit_logs` | management roles; exact minimum requires final screen audit | PENDING |
| CMS | Pages / FAQs / testimonials / videos / promotions | corresponding CMS tables | content_manager / manager / super_admin target where already defined | PARTIAL — exact policy/action audit pending |
| Management | Categories / coupons / delivery configuration / partners / couriers | corresponding tables + admin RPCs | operation-specific privileged roles | PARTIAL — final action matrix pending |
| Settings | Project/module configuration | internal configuration / management contracts | super_admin target | PENDING final action audit |

## Guest-safe functions

These remain intentionally exposed until their complete caller contracts are verified:

- `create_order`
- `quote_delivery`
- `track_order`
- `validate_coupon`
- `record_app_error`

Exposure does not by itself establish that their bodies are safe; each must remain server-authoritative and constrained.

## Repository-only grant hardening already prepared

- `apply_pricing_recommendation`: remove anon.
- `fail_order_payment`: service_role only.
- trigger/internal notification and history helpers: remove anon/authenticated Data API execution.
- `admin_replace_product_main_image`: remove anon.
- `courier_login_status`: remove anon.
- `link_current_user_customer`: remove anon.

These migrations are NOT production deployed.

## Broad `is_staff()` policies

Current live `is_staff()` semantics grant staff status to any user with any `user_roles` row. Because this is broader than the screen-by-role model, broad policies must be replaced only after every screen/action is mapped to its minimum required role.

Decision: KEEP LIVE policies unchanged until this matrix is completed and reviewed.

## Verification gates

1. Complete exact button/action inventory from every admin screen.
2. Map each action to its table/RPC/Edge Function.
3. Confirm minimum role against the actual function body and live RLS policy.
4. Test with non-production role fixtures.
5. Prepare one narrow rollback-safe migration.
6. Run Supabase security/performance advisors.
7. Re-run Flutter analyze/test/build.
8. Only then consider production deployment.
