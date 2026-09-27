-- Reconciliation-only Inventory + Delivery RLS hardening.
-- Live policy names and function authorization were verified on production
-- before preparing this migration.
-- DO NOT deploy until non-production role fixtures validate the matrix.
--
-- Principle:
--   * inventory read/write follows the existing inventory function boundary.
--   * delivery direct management follows delivery_ops_authorized().
--   * courier-assigned read policies remain separately scoped.
--   * no user-role assignments are changed here.

drop policy if exists staff_warehouse_stock_read on public.warehouse_stock;
drop policy if exists staff_inventory_read on public.stock_movements;
drop policy if exists staff_reservations_read on public.stock_reservations;
drop policy if exists staff_couriers_manage on public.couriers;
drop policy if exists staff_delivery_partners_manage on public.delivery_partners;
drop policy if exists staff_delivery_manage on public.delivery_zones;
drop policy if exists staff_shipments_manage on public.shipments;
drop policy if exists staff_delivery_events_manage on public.delivery_events;
drop policy if exists staff_pod_manage on public.proof_of_delivery;

create policy staff_warehouse_stock_read
on public.warehouse_stock
for select
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
  or has_role('inventory_officer')
);

create policy staff_inventory_read
on public.stock_movements
for select
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
  or has_role('inventory_officer')
);

create policy staff_reservations_read
on public.stock_reservations
for select
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
  or has_role('inventory_officer')
);

create policy staff_couriers_manage
on public.couriers
for all
to authenticated
using (delivery_ops_authorized())
with check (delivery_ops_authorized());

create policy staff_delivery_partners_manage
on public.delivery_partners
for all
to authenticated
using (delivery_ops_authorized())
with check (delivery_ops_authorized());

create policy staff_delivery_manage
on public.delivery_zones
for all
to authenticated
using (delivery_ops_authorized())
with check (delivery_ops_authorized());

create policy staff_shipments_manage
on public.shipments
for all
to authenticated
using (delivery_ops_authorized())
with check (delivery_ops_authorized());

create policy staff_delivery_events_manage
on public.delivery_events
for all
to authenticated
using (delivery_ops_authorized())
with check (delivery_ops_authorized());

create policy staff_pod_manage
on public.proof_of_delivery
for all
to authenticated
using (delivery_ops_authorized())
with check (delivery_ops_authorized());
