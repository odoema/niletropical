-- Reconciliation-only Orders RLS hardening.
-- Production policy names were verified directly before creating this migration.
-- DO NOT deploy until non-production role fixtures validate the matrix.

drop policy if exists staff_orders_manage on public.orders;
drop policy if exists staff_orders_read on public.orders;
drop policy if exists staff_order_items_manage on public.order_items;
drop policy if exists staff_order_items_read on public.order_items;
drop policy if exists staff_order_history_manage on public.order_status_history;
drop policy if exists staff_order_history_read on public.order_status_history;

create policy staff_orders_manage
on public.orders
for all
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
)
with check (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
);

create policy staff_orders_read
on public.orders
for select
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
  or has_role('finance')
);

create policy staff_order_items_manage
on public.order_items
for all
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
)
with check (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
);

create policy staff_order_items_read
on public.order_items
for select
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
  or has_role('finance')
);

create policy staff_order_history_manage
on public.order_status_history
for all
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
)
with check (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
);

create policy staff_order_history_read
on public.order_status_history
for select
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
  or has_role('finance')
);
