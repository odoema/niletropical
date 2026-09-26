-- Nile Tropical authorization/lifecycle reconciliation.
-- REPOSITORY-ONLY migration: do not apply to production until role-fixture tests pass.
-- Production authority: ououfhsswyqutcczdtnb

-- 1. Repair an internal lifecycle mismatch: payment_failed is handled by the
-- transition matrix but was missing from the accepted status list.
create or replace function public.update_order_status(
  p_order_id uuid,
  p_new_status text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_order public.orders;
  v_old text;
  v_allowed boolean := false;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not (
    public.has_role('super_admin'::public.app_role)
    or public.has_role('manager'::public.app_role)
    or public.has_role('sales_staff'::public.app_role)
  ) then
    raise exception 'insufficient role';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  v_old := v_order.status;

  if p_new_status is null or p_new_status not in (
    'new_order','payment_pending','payment_confirmed','payment_failed',
    'order_confirmed','processing','packed','ready_for_dispatch',
    'dispatched','in_transit','arrived_at_destination','out_for_delivery',
    'delivered','cancelled','refunded','delivery_failed',
    'customer_unavailable','returned','out_of_stock'
  ) then
    raise exception 'invalid order status';
  end if;

  if p_new_status = v_old then
    return jsonb_build_object('order_id', v_order.id, 'status', v_order.status);
  end if;

  v_allowed := (v_old, p_new_status) in (
    ('new_order','payment_pending'),
    ('new_order','order_confirmed'),
    ('new_order','cancelled'),
    ('new_order','out_of_stock'),
    ('payment_pending','payment_confirmed'),
    ('payment_pending','payment_failed'),
    ('payment_pending','cancelled'),
    ('payment_confirmed','order_confirmed'),
    ('payment_confirmed','cancelled'),
    ('order_confirmed','processing'),
    ('order_confirmed','cancelled'),
    ('processing','packed'),
    ('processing','out_of_stock'),
    ('processing','cancelled'),
    ('packed','ready_for_dispatch'),
    ('packed','cancelled'),
    ('ready_for_dispatch','dispatched'),
    ('ready_for_dispatch','cancelled'),
    ('dispatched','in_transit'),
    ('dispatched','arrived_at_destination'),
    ('dispatched','out_for_delivery'),
    ('dispatched','delivery_failed'),
    ('in_transit','arrived_at_destination'),
    ('in_transit','delivery_failed'),
    ('arrived_at_destination','out_for_delivery'),
    ('arrived_at_destination','delivered'),
    ('out_for_delivery','delivered'),
    ('out_for_delivery','customer_unavailable'),
    ('out_for_delivery','delivery_failed'),
    ('customer_unavailable','out_for_delivery'),
    ('customer_unavailable','returned'),
    ('delivery_failed','out_for_delivery'),
    ('delivery_failed','returned'),
    ('delivered','refunded'),
    ('returned','refunded')
  );

  if not v_allowed then
    raise exception 'invalid status transition from % to %', v_old, p_new_status;
  end if;

  update public.orders
  set status = p_new_status, updated_at = now()
  where id = p_order_id
  returning * into v_order;

  insert into public.order_status_history(order_id,status,note,changed_by)
  values (p_order_id,p_new_status,p_note,auth.uid());

  insert into public.audit_logs(
    user_id,action,entity_type,entity_id,previous_data,new_data
  )
  values (
    auth.uid(),
    'order_status_changed',
    'order',
    p_order_id::text,
    jsonb_build_object('status',v_old),
    jsonb_build_object('status',p_new_status,'note',p_note)
  );

  return jsonb_build_object('order_id',v_order.id,'status',v_order.status);
end;
$function$;

-- 2. Replace broad is_staff() access on operational tables with the role
-- boundaries already documented in docs/auth-rls-role-matrix.md.
-- The existing policy names are retained so this is an auditable replacement.

drop policy if exists staff_orders_read on public.orders;
create policy staff_orders_read on public.orders
for select to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_orders_manage on public.orders;
create policy staff_orders_manage on public.orders
for all to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_order_items_read on public.order_items;
create policy staff_order_items_read on public.order_items
for select to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_order_items_manage on public.order_items;
create policy staff_order_items_manage on public.order_items
for all to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_order_history_read on public.order_status_history;
create policy staff_order_history_read on public.order_status_history
for select to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_order_history_manage on public.order_status_history;
create policy staff_order_history_manage on public.order_status_history
for all to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_customers_manage on public.customers;
create policy staff_customers_manage on public.customers
for all to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists own_address_access on public.customer_addresses;
create policy own_address_access on public.customer_addresses
for all to authenticated
using (
  customer_id in (
    select c.id
    from public.customers c
    where c.user_id = (select auth.uid())
  )
  or (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  customer_id in (
    select c.id
    from public.customers c
    where c.user_id = (select auth.uid())
  )
  or (select has_role('manager'::public.app_role))
  or (select has_role('sales_staff'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_delivery_partners_manage on public.delivery_partners;
create policy staff_delivery_partners_manage on public.delivery_partners
for all to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_couriers_manage on public.couriers;
create policy staff_couriers_manage on public.couriers
for all to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_delivery_manage on public.delivery_zones;
create policy staff_delivery_manage on public.delivery_zones
for all to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('inventory_officer'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  (select has_role('manager'::public.app_role))
  or (select has_role('inventory_officer'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_inventory_read on public.stock_movements;
create policy staff_inventory_read on public.stock_movements
for select to authenticated
using (
  (select has_role('inventory_officer'::public.app_role))
  or (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_reservations_read on public.stock_reservations;
create policy staff_reservations_read on public.stock_reservations
for select to authenticated
using (
  (select has_role('inventory_officer'::public.app_role))
  or (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_warehouse_stock_read on public.warehouse_stock;
create policy staff_warehouse_stock_read on public.warehouse_stock
for select to authenticated
using (
  (select has_role('inventory_officer'::public.app_role))
  or (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_notification_logs_read on public.notification_logs;
create policy staff_notification_logs_read on public.notification_logs
for select to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('finance'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists staff_coupon_redemptions_read on public.coupon_redemptions;
create policy staff_coupon_redemptions_read on public.coupon_redemptions
for select to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('finance'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists website_media_slots_staff_read on public.website_media_slots;
create policy website_media_slots_staff_read on public.website_media_slots
for select to authenticated
using (
  (select has_role('content_manager'::public.app_role))
  or (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

drop policy if exists own_profile_select on public.profiles;
create policy own_profile_select on public.profiles
for select to authenticated
using (
  (select auth.uid()) = id
  or (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);

-- Direct POD writes should not be the browser's authorization boundary.
-- Couriers use submit_proof_of_delivery(), which performs assigned-shipment
-- authorization. Managers/super-admins may inspect/manage POD rows directly.
drop policy if exists staff_pod_manage on public.proof_of_delivery;
create policy staff_pod_manage on public.proof_of_delivery
for all to authenticated
using (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
)
with check (
  (select has_role('manager'::public.app_role))
  or (select has_role('super_admin'::public.app_role))
);
