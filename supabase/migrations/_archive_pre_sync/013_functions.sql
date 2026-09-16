-- Nile Tropical Uganda — 013_functions.sql
-- The three pieces of server-side logic the audit flagged as critical gaps:
--   1. generate_order_number()   — replaces order_service.dart's client-side
--                                   timestamp-based number (collision risk).
--   2. adjust_stock()            — replaces inventory_service.dart's unsafe
--                                   client read→calculate→write (overselling
--                                   / race-condition risk). Row-locks the
--                                   variant so concurrent sales cannot both
--                                   succeed against the same units.
--   3. order status transition guard — enforces §28's valid-transition rule
--                                   and automatically writes to
--                                   order_status_history on every change.

-- ---------------------------------------------------------------------
-- 1. Order numbers: NTI-<year>-<6-digit sequence>, e.g. NTI-2026-000001
-- ---------------------------------------------------------------------
create or replace function generate_order_number()
returns text
language plpgsql
as $$
declare
  next_val bigint;
begin
  next_val := nextval('order_number_seq');
  return 'NTI-' || extract(year from now())::text || '-' ||
         lpad(next_val::text, 6, '0');
end;
$$;

-- ---------------------------------------------------------------------
-- 2. Atomic, concurrency-safe stock adjustment.
--    Locks the variant row (SELECT ... FOR UPDATE) before checking and
--    writing stock, so two simultaneous sales cannot both read the same
--    stale stock_quantity and both succeed. Raises a recognizable
--    INSUFFICIENT_STOCK error (never silently clamps to zero — §14).
-- ---------------------------------------------------------------------
create or replace function adjust_stock(
  p_variant_id uuid,
  p_quantity int,              -- positive = increase, negative = decrease
  p_movement_type stock_movement_type,
  p_reference text default null,
  p_notes text default null,
  p_batch_id uuid default null,
  p_created_by uuid default null
)
returns table (new_stock_quantity int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current int;
begin
  if p_quantity = 0 then
    raise exception 'ZERO_QUANTITY_MOVEMENT' using errcode = 'P0001';
  end if;

  -- Row lock: any concurrent adjust_stock() call for the same variant
  -- blocks here until this transaction commits or rolls back.
  select stock_quantity into v_current
  from product_variants
  where id = p_variant_id
  for update;

  if not found then
    raise exception 'VARIANT_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_current + p_quantity < 0 then
    raise exception 'INSUFFICIENT_STOCK: variant % has % in stock, requested change %',
      p_variant_id, v_current, p_quantity
      using errcode = 'P0003';
  end if;

  update product_variants
  set stock_quantity = v_current + p_quantity
  where id = p_variant_id;

  insert into stock_movements (
    product_variant_id, batch_id, movement_type, quantity,
    reference, notes, created_by
  ) values (
    p_variant_id, p_batch_id, p_movement_type, p_quantity,
    p_reference, p_notes, p_created_by
  );

  return query select (v_current + p_quantity);
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Order status transition guard + automatic history logging (§27, §28).
--    A customer/client can never move an order backwards or skip the
--    defined lifecycle by writing to `orders.status` directly — only the
--    transitions listed below are permitted. Cancellation/return/refund
--    are reachable from any non-terminal state as documented exceptions.
-- ---------------------------------------------------------------------
create or replace function validate_order_status_transition()
returns trigger
language plpgsql
as $$
declare
  v_allowed boolean := false;
  v_terminal order_status[] := array[
    'delivered', 'cancelled', 'refunded', 'returned'
  ]::order_status[];
begin
  if TG_OP = 'INSERT' then
    return new;
  end if;

  if old.status = new.status then
    return new; -- no status change, nothing to validate/log
  end if;

  if old.status = any(v_terminal) then
    raise exception 'INVALID_STATUS_TRANSITION: order % is already in terminal status %',
      old.order_number, old.status
      using errcode = 'P0004';
  end if;

  v_allowed := case old.status
    when 'new' then new.status in ('payment_pending', 'payment_confirmed', 'cancelled', 'out_of_stock')
    when 'payment_pending' then new.status in ('payment_confirmed', 'cancelled')
    when 'payment_confirmed' then new.status in ('order_confirmed', 'cancelled', 'refunded')
    when 'order_confirmed' then new.status in ('processing', 'cancelled', 'out_of_stock')
    when 'processing' then new.status in ('packed', 'cancelled', 'out_of_stock')
    when 'packed' then new.status in ('ready_for_dispatch', 'cancelled')
    when 'ready_for_dispatch' then new.status in ('dispatched', 'cancelled')
    when 'dispatched' then new.status in ('in_transit', 'delivery_failed')
    when 'in_transit' then new.status in ('arrived_at_destination', 'delivery_failed')
    when 'arrived_at_destination' then new.status in ('out_for_delivery', 'delivery_failed')
    when 'out_for_delivery' then new.status in ('delivered', 'delivery_failed')
    when 'delivery_failed' then new.status in ('out_for_delivery', 'returned', 'cancelled')
    when 'out_of_stock' then new.status in ('cancelled', 'processing')
    else false
  end;

  if not v_allowed then
    raise exception 'INVALID_STATUS_TRANSITION: % -> % is not permitted for order %',
      old.status, new.status, old.order_number
      using errcode = 'P0004';
  end if;

  insert into order_status_history (order_id, from_status, to_status, changed_by)
  values (new.id, old.status, new.status, auth.uid());

  return new;
end;
$$;

create trigger enforce_order_status_transition
  before insert or update of status on orders
  for each row execute function validate_order_status_transition();
