-- Nile Tropical — distance-aware delivery quotes and order snapshots
-- 2026-09-26
--
-- Server-authoritative quote:
-- base fee is UGX 2,500;
-- each road km is charged at UGX 450;
-- the quote is server-authoritative.
-- The customer may display the quote client-side, but create_order recalculates it.

alter table public.orders
  add column if not exists delivery_distance_km numeric,
  add column if not exists delivery_duration_minutes numeric,
  add column if not exists delivery_origin_snapshot jsonb,
  add column if not exists delivery_destination_snapshot jsonb;

create or replace function public.quote_delivery(
  p_delivery_zone_id uuid,
  p_distance_km numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base_fee numeric := 2500;
  v_extra_km_rate numeric := 450;
  v_total numeric := 0;
  v_zone_name text;
begin
  if p_distance_km is null or p_distance_km < 0 then
    raise exception 'INVALID_DISTANCE: %', p_distance_km using errcode = 'P0001';
  end if;

  select name into v_zone_name
  from public.delivery_zones
  where id = p_delivery_zone_id
    and is_active = true;

  if not found then
    raise exception 'INVALID_DELIVERY_ZONE: %', p_delivery_zone_id using errcode = 'P0002';
  end if;

  v_total := round(v_base_fee + (greatest(p_distance_km, 0) * v_extra_km_rate), 0);

  return jsonb_build_object(
    'zone_id', p_delivery_zone_id,
    'zone_name', v_zone_name,
    'distance_km', round(p_distance_km, 2),
    'included_km', 0,
    'extra_km', round(greatest(p_distance_km, 0), 2),
    'extra_km_units', 0,
    'base_fee', v_base_fee,
    'extra_km_rate', v_extra_km_rate,
    'delivery_fee', v_total,
    'pricing_model', 'safeboda_like',
    'currency', 'UGX'
  );
end;
$$;

grant execute on function public.quote_delivery(uuid, numeric) to anon, authenticated;

-- Ten-argument production create_order entry point.
-- It delegates all inventory/customer/payment validation to the canonical
-- nine-argument function, then replaces the zone-only fee with the
-- server-recalculated distance quote in the same database transaction.
create or replace function public.create_order(
  p_idempotency_key text,
  p_full_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_delivery_zone_id uuid,
  p_payment_method text,
  p_items jsonb,
  p_notes text,
  p_delivery_distance_km numeric,
  p_delivery_duration_minutes numeric default null,
  p_delivery_origin jsonb default null,
  p_delivery_destination jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_created jsonb;
  v_quote jsonb;
  v_order_id uuid;
  v_subtotal numeric;
  v_delivery_fee numeric;
  v_total numeric;
begin
  if p_delivery_distance_km is null then
    raise exception 'DELIVERY_DISTANCE_REQUIRED' using errcode = 'P0001';
  end if;

  v_created := public.create_order(
    p_idempotency_key,
    p_full_name,
    p_phone,
    p_email,
    p_address,
    p_delivery_zone_id,
    p_payment_method,
    p_items,
    p_notes
  );

  v_order_id := (v_created->>'order_id')::uuid;

  -- Idempotent replay: return the original server quote.
  if coalesce((v_created->>'idempotent')::boolean, false) then
    return v_created;
  end if;

  v_quote := public.quote_delivery(
    p_delivery_zone_id,
    p_delivery_distance_km
  );

  v_delivery_fee := (v_quote->>'delivery_fee')::numeric;

  select subtotal
    into v_subtotal
  from public.orders
  where id = v_order_id
  for update;

  v_total := v_subtotal + v_delivery_fee;

  update public.orders
  set
    delivery_fee = v_delivery_fee,
    total = v_total,
    delivery_distance_km = p_delivery_distance_km,
    delivery_duration_minutes = p_delivery_duration_minutes,
    delivery_origin_snapshot = p_delivery_origin,
    delivery_destination_snapshot = p_delivery_destination
  where id = v_order_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_created->>'order_number',
    'total', v_total,
    'delivery_fee', v_delivery_fee,
    'delivery_distance_km', p_delivery_distance_km,
    'delivery_duration_minutes', p_delivery_duration_minutes,
    'idempotent', false
  );
end;
$$;

grant execute on function public.create_order(
  text,text,text,text,text,uuid,text,jsonb,text,numeric,numeric,jsonb,jsonb
) to anon, authenticated;
