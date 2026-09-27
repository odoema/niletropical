# Authorization reconciliation — 2026-09-27

## LIVE VERIFIED

Production target: ououfhsswyqutcczdtnb.

The broad policy issue is confirmed: is_staff() currently means any assigned application role.

### REPAIR candidates

- orders: staff_orders_manage / staff_orders_read — narrow to documented order-operation roles.
- order_items: staff_order_items_manage / staff_order_items_read — follow order permissions.
- order_status_history: staff_order_history_manage / staff_order_history_read — follow order lifecycle permissions.
- customers: staff_customers_manage — narrow to customer/order-operation roles.
- customer_addresses: own_address_access — retain owner access; narrow staff branch.
- couriers: staff_couriers_manage — follow delivery_ops_authorized().
- delivery_partners: staff_delivery_partners_manage — follow delivery_ops_authorized().
- delivery_zones: staff_delivery_manage — follow delivery_ops_authorized().
- delivery_events: staff_delivery_events_manage — follow delivery_ops_authorized(); assigned-courier read remains separately scoped.
- shipments: staff_shipments_manage — follow delivery_ops_authorized(); assigned-courier read remains separately scoped.
- proof_of_delivery: staff_pod_manage — follow delivery_ops_authorized(); assigned courier remains controlled through submit_proof_of_delivery().
- stock_movements, stock_reservations, warehouse_stock — inventory operational roles only.
- notification_logs — narrow after confirming operational/finance reporting needs.
- website_media_slots — content_manager/manager/super_admin.

## ORDERS — REPOSITORY REPAIR PREPARED

Live policy names and expressions were verified directly in production before creating the migration.

Repository-only migration:
supabase/migrations/20260927_repair_orders_rls_roles.sql

Proposed role boundary:
- Orders/order items/history read: super_admin, manager, sales_staff, finance.
- Orders/order items/history direct mutation: super_admin, manager, sales_staff.
- Customer-owned read policies remain separate.
- No production role assignments are changed.

This migration is REPOSITORY / PENDING REVIEW / NOT DEPLOYED.

## INVENTORY + DELIVERY — REPOSITORY REPAIR PREPARED

Live policy names were verified directly in production.

Repository-only migration:
supabase/migrations/20260927_repair_inventory_delivery_rls_roles.sql

Prepared boundary:
- Inventory reads: super_admin, manager, sales_staff, inventory_officer.
- Delivery management: delivery_ops_authorized(), which requires an authenticated user with super_admin, manager, sales_staff, or inventory_officer.
- Assigned-courier shipment/event reads remain separately scoped to the assigned courier, manager, or super_admin.
- Public active delivery-zone read remains KEEP.
- No role assignments are changed.

This migration is REPOSITORY / PENDING REVIEW / NOT DEPLOYED.

## KEEP

- Owner policies for customer-owned records.
- Assigned-courier shipment/event read policies.
- Explicit content, pricing, payment, COD and error-log role policies.
- SECURITY DEFINER function guards already enforcing minimum roles.
- Public guest track_order(order_number, phone) path.

## CUSTOMERS / NOTIFICATIONS / MEDIA — REPOSITORY REPAIR PREPARED

Repository-only migration: `supabase/migrations/20260927_repair_customers_notifications_rls.sql`

Prepared boundaries:
- Customers direct management: super_admin / manager / sales_staff.
- Customer addresses: owner plus super_admin / manager / sales_staff.
- Notification log read: super_admin / manager / finance.
- Website media staff read: super_admin / manager / content_manager.

No production role assignments are changed. NOT DEPLOYED.

## FUNCTION GRANT HARDENING — REPOSITORY REPAIR PREPARED

Repository-only migration: `supabase/migrations/20260927_harden_internal_security_definer_grants.sql`

Prepared hardening:
- `apply_pricing_recommendation(uuid)`: remove anon execution.
- `fail_order_payment(uuid,text)`: remove anon/authenticated execution; retain service_role because no current Flutter/payment Edge caller was found and the function mutates payment/order state.
- trigger-only notification/history helpers: remove anon/authenticated execution.
- notification queue helpers: remove anon/authenticated execution because current lifecycle trigger is their verified caller.
- `admin_replace_product_main_image(...)`: remove anon execution; retain authenticated/service_role.

This is REPOSITORY / PENDING REVIEW / NOT DEPLOYED.

## TRIGGER SEARCH PATH — REPOSITORY REPAIR PREPARED

Repository-only migration: `supabase/migrations/20260927_harden_trigger_function.sql`

Prepared hardening:
- set `public.trigger_set_updated_at()` search_path explicitly to `public`.
- remove direct anon/authenticated execution because it is a trigger-only helper.

NOT DEPLOYED.

## BRANCH DIVERGENCE — LIVE RECONCILIATION

master is 1 commit ahead and the reconciliation branch is 49 commits ahead from merge-base 249a0f61a40259ae90cef218b2a6274360033a05.

The master-only commit is:
fd3ac280994468787394738d58f7f43cf29b0b02 — fix: record live Supabase reconciliation

It adds:
supabase/migrations/20260927_live_reconciliation.sql

The reconciliation branch has not blindly rebased or reset. The master-only migration is already LIVE-VERIFIED in production, but its history must be preserved deliberately during final integration because replaying historical migrations is not part of this reconciliation.

## HOLD

Do not mechanically replace remaining is_staff() policies, mutate production role assignments, deploy lifecycle repairs, or deploy Edge Functions during this reconciliation stage.

## Next testable units

1. Validate Orders policy role boundary in a non-production fixture environment.
2. Validate Inventory/Delivery role boundaries in a non-production fixture environment.
3. Reconcile Customers/COD/Finance.
4. Reconcile Notifications/Audit/Analytics.
5. Resolve branch integration strategy without replaying historical migrations.
6. Run security/performance advisors after any approved production RLS changes.
