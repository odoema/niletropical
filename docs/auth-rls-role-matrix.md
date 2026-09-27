# Nile Tropical — Auth/RLS Role Matrix

Date: 2026-09-27
Branch: `reconcile/live-supabase-20260927`
Production authority: `ououfhsswyqutcczdtnb`

## Purpose

This is the authorization reconciliation baseline. It separates:
1. what the Flutter UI exposes,
2. what the database currently permits,
3. what role should be required.

No production RLS changes are implied by this document.

## Role baseline

| Role | Intended scope |
|---|---|
| super_admin | Full administration, configuration and oversight |
| manager | Operational management and management reports |
| finance | Payments, COD and financial reporting |
| inventory_officer | Stock, warehouses and inventory movements |
| content_manager | Catalogue/content/CMS publishing |
| sales_staff | Sales/order operations where explicitly supported by backend functions |
| courier | Assigned delivery execution and POD |
| customer/public | Storefront, checkout and phone-verified guest tracking |

## Screen/action matrix

| Screen | Action | Backend surface | Minimum intended role | Current live authorization | Classification |
|---|---|---|---|---|---|
| Orders | Read order list/detail | orders, order_items, order_status_history | manager / sales_staff / super_admin | is_staff() | REPAIR candidate |
| Orders | Change order status | update_order_status() | manager / sales_staff / super_admin | function explicitly checks these roles | KEEP |
| Inventory | Read stock/movements | product_variants, warehouse_stock, stock_movements, stock_reservations | inventory_officer / manager / super_admin | several reads use is_staff() | REPAIR candidate |
| Inventory | Record stock movement | record_stock_movement() | inventory_officer / manager / super_admin | function explicitly checks these roles | KEEP |
| Delivery | Create/edit delivery zone | admin_create_delivery_zone() | manager / inventory_officer / super_admin | function uses delivery_ops_authorized() | KEEP function; policy review |
| Delivery | Create courier | admin_create_courier() | manager / super_admin | function is SECURITY DEFINER; exact body requires final inspection | VERIFY |
| Delivery | Assigned shipment/event read | shipments, delivery_events | courier / manager / super_admin | assigned courier or manager/super_admin policy exists | KEEP |
| Delivery | Delivery/POD execution | submit_proof_of_delivery() | assigned courier / delivery ops | function checks delivery ops or assigned courier | KEEP |
| Customers | Read/manage customers | customers, customer_addresses | manager / sales_staff / super_admin | is_staff() | REPAIR candidate |
| COD/Finance | Read/manage COD | cod_collections | finance / manager / super_admin | explicit role policy | KEEP |
| Payments | Read payment transactions | payment_transactions | finance / manager / super_admin | explicit role policy | KEEP |
| Payments | Read webhook events | payment_webhook_events | finance / manager / super_admin | explicit role policy | KEEP |
| Products | Manage products/images/videos | products, product_images, product_videos | content_manager / manager / super_admin; variants also inventory_officer | explicit role policies | KEEP |
| Pricing | Read/update recommendations | pricing_recommendations | manager / finance / super_admin | explicit role policies | KEEP |
| Pricing | Apply approved price | apply_pricing_recommendation() | manager / super_admin | function explicitly checks role | KEEP |
| CMS | Manage pages/FAQs/banners/testimonials/videos/promotions | CMS tables | content_manager / manager / super_admin | explicit role policies | KEEP |
| Notifications | Manage templates | notification_templates | content_manager / manager / super_admin | explicit role policy | KEEP |
| Notifications | Read notification logs | notification_logs | manager / finance / super_admin (subject to operational need) | is_staff() | REPAIR candidate |
| Reports | Read order aggregates | orders | manager / finance / super_admin, depending report | is_staff() on orders | REPAIR candidate |
| Analytics | Dashboard function + order aggregates | analytics-dashboard, orders | manager / finance / super_admin | function/auth policy requires final verification; order reads use is_staff() | VERIFY / REPAIR candidate |
| Audit | Read audit history | audit_logs / nile_admin.admin_activity_log | manager / super_admin | audit_logs policy explicit; nile_admin path requires final access verification | VERIFY |
| Error logs | Read/resolve | app_error_logs | manager / finance / super_admin | explicit role policy | KEEP |
| Management | Categories | categories | content_manager / manager / super_admin | explicit role policy | KEEP |
| Management | Coupons | coupons | content_manager / manager / super_admin | explicit role policy | KEEP |
| Management | Delivery partners/couriers | delivery_partners/couriers | manager / super_admin | is_staff() on direct table paths | REPAIR candidate |
| Settings | Browser application preferences | local/application state | authenticated admin user as appropriate | no production DB write shown | KEEP / VERIFY UI gate |

## Critical live RLS finding

The production helper `is_staff()` returns true when the current authenticated user has **any** `user_roles` row. It is therefore not equivalent to “manager/admin”.

The live policy inventory contains **20 policies** using `is_staff()` in SELECT/ALL/UPDATE/ownership expressions. These cover orders, customers, delivery, stock reads, notifications, POD, profiles, coupon-redemption reads and website-media staff reads.

This is not being fixed by redefining `is_staff()`. A bulk change would be unsafe because different screens require different roles.

## Function-level authorization already stronger than some table policies

Verified SECURITY DEFINER functions include:
- `update_order_status()`
- `record_stock_movement()`
- `admin_create_delivery_zone()`
- `submit_proof_of_delivery()`
- `apply_pricing_recommendation()`
- `delivery_ops_authorized()`

Where these functions enforce role checks, the frontend should prefer the function rather than direct table mutation.

## Immediate policy decisions

### KEEP
- Explicit role policies for payments, COD, pricing, CMS, products/content, error logs.
- Assigned-courier shipment/event read controls.
- Function-level authorization already enforcing minimum roles.

### REPAIR
Review broad `is_staff()` table policies individually:
- orders / order_items / order_status_history
- customers / customer_addresses
- delivery_partners / delivery_zones / couriers / delivery_events / shipments where direct CRUD is exposed
- stock_movements / stock_reservations / warehouse_stock reads
- notification_logs
- coupon_redemptions
- website_media_slots staff read
- profile staff read
- proof_of_delivery

### DO NOT CHANGE YET
- `is_staff()` definition itself.
- Production RLS policies.
- Role assignments.
- Existing production data.

## Evidence limitation

The current production `user_roles` table contains only users assigned the `super_admin` role in the observed aggregate. Therefore narrower-role behavior cannot be safely simulated by modifying production role assignments. Final authorization tests for courier, inventory_officer, content_manager, finance and manager should use approved test identities/environments or controlled non-production role fixtures.

## Next execution step

1. Inspect remaining management/courier/audit/analytics function bodies.
2. Verify direct table mutations versus function-only paths.
3. Produce one narrow RLS migration for only proven mismatches.
4. Run security/performance advisors.
5. Run Flutter validation.
6. Review the diff before any merge or deployment.

No deployment is part of this step.
