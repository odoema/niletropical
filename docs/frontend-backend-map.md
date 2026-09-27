# Nile Tropical — Frontend / Backend Map

Repository: `odoema/niletropical`
Production backend authority: `ououfhsswyqutcczdtnb`

## Authoritative role model — audit baseline

| Role | Intended responsibility boundary |
|---|---|
| super_admin | Full administration and configuration |
| manager | Operational management across orders, delivery, catalogue and approved business workflows |
| finance | Payments, COD reconciliation, financial reporting |
| inventory_officer | Stock, warehouses, inventory movements |
| content_manager | Catalogue/content/CMS publishing |
| courier | Assigned delivery execution and proof-of-delivery workflow |
| customer/public | Storefront, checkout and phone-verified guest order tracking |

**Important:** this is the intended audit baseline, not permission proof. Live RLS must be checked for every action before any policy change.

## Screen-by-screen audit matrix

| Screen/area | Typical actions | Backend surface | Intended role | RLS/auth state |
|---|---|---|---|---|
| Admin Dashboard | View operational KPIs | orders, stock aggregates, analytics-dashboard | manager, super_admin; finance/inventory views as applicable | REVIEW |
| Orders | List/view/update order status | orders, order_items, order_status_history, update_order_status() | manager, super_admin | REVIEW — broad is_staff policy |
| Inventory | View/adjust stock | warehouse_stock, stock_movements, record_stock_movement() | inventory_officer, manager, super_admin | REVIEW — broad staff read |
| Delivery | Zones/partners/couriers/shipments/events | delivery_zones, delivery_partners, couriers, shipments, delivery_events | manager, super_admin; courier only assigned delivery actions | REVIEW |
| Customers | View/manage customers and addresses | customers, customer_addresses | manager, super_admin | REVIEW — broad staff policy |
| COD / Finance | Reconcile COD, inspect payment state | cod_collections, payment_transactions, payment_webhook_events | finance, manager, super_admin | PARTLY VERIFIED — finance boundary exists |
| Products | Catalogue CRUD | products, product_variants, product_images | content_manager, manager, super_admin | PARTLY VERIFIED |
| Pricing | Review/apply recommendations | pricing_recommendations, apply_pricing_recommendation() | finance/manager/super_admin according to action | VERIFIED at policy level; UI still reviewed |
| CMS | Pages, FAQs, testimonials, videos, promotions, media slots | CMS tables/storage | content_manager, manager, super_admin | REVIEW — policy role boundaries require final screen audit |
| Reports | Operational/financial reports | orders, stock, payments, analytics surfaces | manager, finance, inventory_officer as report scope dictates | REVIEW |
| Analytics | Dashboard metrics | analytics-dashboard Edge Function + order aggregates | manager, finance, super_admin | REVIEW |
| Notifications | Templates/logs/push administration | notification_templates, notification_logs, push_subscriptions, notification-dispatch | manager, content_manager where appropriate; operational read by authorized roles | REVIEW |
| Audit logs | View audit trail | audit_logs | manager, super_admin; narrowly scoped access | REVIEW — live SELECT policy needs boundary confirmation |
| Error logs | Review/resolve application errors | app_error_logs, record_app_error() | manager, finance, super_admin | VERIFIED |
| Courier | Assigned jobs, delivery events, POD | shipments, delivery_events, proof_of_delivery | courier for assigned records; manager/super_admin oversight | PARTLY VERIFIED |

## Confirmed reconciliations

- Admin order detail uses live `update_order_status(p_order_id,p_new_status,p_note)`.
- Admin order list/detail uses `customer_name_snapshot`.
- Inventory adjustment uses `record_stock_movement`; obsolete `adjust_stock` is not a live RPC.
- Checkout uses distance-aware `create_order` and authoritative `quote_delivery`.
- Pricing uses `suggested_retail_price` and `apply_pricing_recommendation`.
- Customer/COD screens use live customer/order/COD fields.
- Delivery zone/courier calls match live RPC signatures.
- Tracking uses the canonical `track-order` Edge Function.
- Payment architecture uses canonical `payment_transactions`; Flutterwave remains legacy/reference only.

## Critical RLS finding

The live `is_staff()` helper currently treats a user with any `user_roles` row as staff. Multiple policies use `is_staff()` for broad access. This is wider than the intended role model above.

**Do not replace these policies mechanically.** First reconcile each screen/action to the minimum required role, then test the policy predicates and role helper behavior. No production RLS changes have been made as part of this audit.

## Evidence labels

- LIVE VERIFIED — directly checked against production.
- REPOSITORY — present in GitHub.
- RECONCILED — repository matches verified backend contract.
- TESTED — behavior actually executed.
- DEPLOYED — confirmed in live environment.
- UNVERIFIED — evidence missing.

## Safety

No destructive reset, blind migration replay, automatic production `supabase db push`, fabricated production data, or payment-provider substitution is permitted.
