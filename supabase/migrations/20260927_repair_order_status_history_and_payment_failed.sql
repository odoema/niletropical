-- Reconciliation-only order lifecycle repair.
-- Live update_order_status() currently:
--   1) omits payment_failed from its accepted status list even though the
--      transition matrix includes it; and
--   2) inserts order_status_history directly while the live orders trigger
--      record_order_status_history() also records status changes, producing
--      duplicate history rows on successful RPC transitions.
-- DO NOT DEPLOY until role-fixture and lifecycle regression tests pass.

CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id uuid,
  p_new_status text,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_order public.orders;
  v_old text;
  v_allowed boolean := false;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not (
    has_role('super_admin')
    or has_role('manager')
    or has_role('sales_staff')
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

  if p_new_status is null
     or p_new_status not in (
       'new_order',
       'payment_pending',
       'payment_confirmed',
       'payment_failed',
       'order_confirmed',
       'processing',
       'packed',
       'ready_for_dispatch',
       'dispatched',
       'in_transit',
       'arrived_at_destination',
       'out_for_delivery',
       'delivered',
       'cancelled',
       'refunded',
       'delivery_failed',
       'customer_unavailable',
       'returned',
       'out_of_stock'
     ) then
    raise exception 'invalid order status';
  end if;

  if p_new_status = v_old then
    return jsonb_build_object(
      'order_id', v_order.id,
      'status', v_order.status
    );
  end if;

  v_allowed := (v_old, p_new_status) in (
    ('new_order','payment_pending'),
    ('new_order','order_confirmed'),
    ('new_order','cancelled'),
    ('new_order','out_of_stock'),
    ('payment_pending','payment_confirmed'),
    ('payment_pending','cancelled'),
    ('payment_pending','payment_failed'),
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
  set status = p_new_status,
      updated_at = now()
  where id = p_order_id
  returning * into v_order;

  -- order_status_history is recorded by the canonical orders status trigger.
  -- Keeping a single writer prevents duplicate history entries.

  insert into public.audit_logs(
    user_id,
    action,
    entity_type,
    entity_id,
    previous_data,
    new_data
  )
  values (
    auth.uid(),
    'order_status_changed',
    'order',
    p_order_id::text,
    jsonb_build_object('status', v_old),
    jsonb_build_object('status', p_new_status, 'note', p_note)
  );

  return jsonb_build_object(
    'order_id', v_order.id,
    'status', v_order.status
  );
end;
$function$;

COMMENT ON FUNCTION public.update_order_status(uuid, text, text)
IS
'Authorized order lifecycle transition RPC. payment_failed is a valid transition state, and order_status_history is written by the canonical orders status trigger to avoid duplicate history rows.';
