-- Reconciliation-only Customers + Notifications + Media RLS hardening.
-- Live policy names/expressions were verified on production.
-- DO NOT deploy until non-production role fixtures validate the matrix.
-- No production role assignments are changed.

drop policy if exists staff_customers_manage on public.customers;
create policy staff_customers_manage
on public.customers
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

drop policy if exists own_address_access on public.customer_addresses;
create policy own_address_access
on public.customer_addresses
for all
to authenticated
using (
  customer_id in (
    select c.id
    from public.customers c
    where c.user_id = (select auth.uid())
  )
  or has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
)
with check (
  customer_id in (
    select c.id
    from public.customers c
    where c.user_id = (select auth.uid())
  )
  or has_role('super_admin')
  or has_role('manager')
  or has_role('sales_staff')
);

drop policy if exists staff_notification_logs_read on public.notification_logs;
create policy staff_notification_logs_read
on public.notification_logs
for select
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('finance')
);

drop policy if exists website_media_slots_staff_read on public.website_media_slots;
create policy website_media_slots_staff_read
on public.website_media_slots
for select
to authenticated
using (
  has_role('super_admin')
  or has_role('manager')
  or has_role('content_manager')
);
