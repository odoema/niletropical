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
- couriers: staff_couriers_manage — manager/super_admin operational management.
- delivery_partners: staff_delivery_partners_manage — manager/super_admin.
- delivery_zones: staff_delivery_manage — manager/super_admin.
- delivery_events: staff_delivery_events_manage — operational roles; courier execution should remain controlled.
- shipments: staff_shipments_manage — manager/sales_staff/super_admin as required by actual UI actions.
- proof_of_delivery: staff_pod_manage — manager/super_admin; assigned courier through controlled function.
- stock_movements, stock_reservations, warehouse_stock — inventory_officer/manager/super_admin.
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

## KEEP

- Owner policies for customer-owned records.
- Assigned-courier shipment/event read policies.
- Explicit content, pricing, payment, COD and error-log role policies.
- SECURITY DEFINER function guards already enforcing minimum roles.
- Public guest track_order(order_number, phone) path.

## FUNCTION GRANT HARDENING — REPAIR CANDIDATE

Live metadata shows apply_pricing_recommendation(uuid) is executable by anon as well as authenticated, although its function body requires manager/finance/super_admin. This is defense-in-depth, not an observed authorization bypass. Candidate repository repair exists separately. Do not apply until reviewed.

## HOLD

Do not mechanically replace remaining is_staff() policies, mutate production role assignments, deploy lifecycle repairs, or deploy Edge Functions during this reconciliation stage.

## Next testable units

1. Validate Orders policy role boundary in a non-production fixture environment.
2. Reconcile Inventory direct reads/mutations.
3. Reconcile Delivery/Courier direct reads/mutations.
4. Reconcile Customers/COD/Finance.
5. Reconcile Notifications/Audit/Analytics.
6. Run security/performance advisors after any approved production RLS changes.
