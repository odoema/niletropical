-- 20260928_delivery_pricing_engine.sql
-- Configurable, server-authoritative delivery pricing.
-- Existing delivery_zones.delivery_fee values are preserved as initial flat rules.
-- Business rates must be approved/configured before switching a rule to distance/time pricing.

create table if not exists public.delivery_pricing_rules (
  id uuid primary key default gen_random_uuid(),
  delivery_zone_id uuid references public.delivery_zones(id) on delete restrict,
  delivery_method text not null default 'default'
    check (delivery_method in ('default','boda','transport_terminal','customer_pickup','local_delivery','special','transport_terminal_or_local')),
  pricing_model text not null default 'flat'
    check (pricing_model in ('flat','distance','time_distance')),
  currency text not null default 'UGX' check (currency = 'UGX'),
  base_fee numeric(14,2) not null default 0 check (base_fee >= 0),
  minimum_fee numeric(14,2) not null default 0 check (minimum_fee >= 0),
  included_km numeric(10,3) not null default 0 check (included_km >= 0),
  per_km numeric(14,2) not null default 0 check (per_km >= 0),
  included_minutes numeric(10,2) not null default 0 check (included_minutes >= 0),
  per_minute numeric(14,2) not null default 0 check (per_minute >= 0),
  peak_multiplier numeric(8,4) not null default 1 check (peak_multiplier >= 0),
  peak_start time,
  peak_end time,
  peak_days smallint[] not null default array[1,2,3,4,5,6,7]::smallint[],
  long_distance_threshold_km numeric(10,3),
  long_distance_fee numeric(14,2) not null default 0 check (long_distance_fee >= 0),
  special_fee numeric(14,2) not null default 0 check (special_fee >= 0),
  rounding_increment numeric(14,2) not null default 1 check (rounding_increment > 0),
  active boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  notes text,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (long_distance_threshold_km is null or long_distance_threshold_km >= 0),
  check (effective_until is null or effective_until > effective_from),
  check ((peak_start is null and peak_end is null) or (peak_start is not null and peak_end is not null)),
  check (peak_days <@ array[1,2,3,4,5,6,7]::smallint[])
);

create index if not exists delivery_pricing_rules_lookup_idx
  on public.delivery_pricing_rules
  (delivery_zone_id, delivery_method, active, effective_from, effective_until);

alter table public.orders
  add column if not exists delivery_method text,
  add column if not exists delivery_pricing_rule_id uuid references public.delivery_pricing_rules(id),
  add column if not exists delivery_pricing_snapshot jsonb;

alter table public.delivery_pricing_rules enable row level security;

revoke all on table public.delivery_pricing_rules from anon, authenticated;
grant select, insert, update, delete on table public.delivery_pricing_rules to authenticated;

drop policy if exists delivery_pricing_rules_staff_read on public.delivery_pricing_rules;
create policy delivery_pricing_rules_staff_read
  on public.delivery_pricing_rules
  for select to authenticated
  using ((select public.is_staff()));

drop policy if exists delivery_pricing_rules_manager_write on public.delivery_pricing_rules;
create policy delivery_pricing_rules_manager_write
  on public.delivery_pricing_rules
  for all to authenticated
  using (
    (select public.has_role('super_admin'::public.app_role))
    or (select public.has_role('manager'::public.app_role))
  )
  with check (
    (select public.has_role('super_admin'::public.app_role))
    or (select public.has_role('manager'::public.app_role))
  );

insert into public.delivery_pricing_rules (
  delivery_zone_id, delivery_method, pricing_model, base_fee, minimum_fee,
  included_km, per_km, included_minutes, per_minute, peak_multiplier,
  long_distance_fee, special_fee, notes
)
select
  dz.id,
  coalesce(nullif(dz.delivery_method, ''), 'default'),
  'flat',
  dz.delivery_fee,
  dz.delivery_fee,
  0, 0, 0, 0, 1,
  0, 0,
  'Initial rule preserves the existing production delivery_zones fee. Replace with approved distance/time/peak values before enabling dynamic pricing.'
from public.delivery_zones dz
where dz.is_active
  and not exists (
    select 1
    from public.delivery_pricing_rules r
    where r.delivery_zone_id = dz.id
      and r.delivery_method = coalesce(nullif(dz.delivery_method, ''), 'default')
      and r.active
  );

create or replace function public.quote_delivery(
  p_delivery_zone_id uuid,
  p_distance_km numeric,
  p_duration_minutes numeric default null,
  p_delivery_method text default 'default',
  p_quote_at timestamptz default now()
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_rule public.delivery_pricing_rules%rowtype;
  v_zone_name text;
  v_method text := coalesce(nullif(p_delivery_method, ''), 'default');
  v_distance numeric := greatest(coalesce(p_distance_km, 0), 0);
  v_minutes numeric := greatest(coalesce(p_duration_minutes, 0), 0);
  v_base numeric := 0;
  v_distance_fee numeric := 0;
  v_time_fee numeric := 0;
  v_peak_fee numeric := 0;
  v_long_fee numeric := 0;
  v_special_fee numeric := 0;
  v_raw numeric := 0;
  v_total numeric := 0;
  v_peak boolean := false;
  v_dow smallint := extract(isodow from p_quote_at)::smallint;
  v_t time := p_quote_at::time;
begin
  select dz.name
    into v_zone_name
  from public.delivery_zones dz
  where dz.id = p_delivery_zone_id
    and dz.is_active;

  if v_zone_name is null then
    raise exception 'Delivery zone is not active or does not exist.' using errcode='P0002';
  end if;

  select r.*
    into v_rule
  from public.delivery_pricing_rules r
  where r.delivery_zone_id = p_delivery_zone_id
    and (v_method = 'default' or r.delivery_method in (v_method, 'default'))
    and r.active
    and r.effective_from <= p_quote_at
    and (r.effective_until is null or r.effective_until > p_quote_at)
  order by
    case
      when v_method <> 'default' and r.delivery_method = v_method then 0
      when r.delivery_method = 'default' then 1
      else 2
    end,
    r.effective_from desc
  limit 1;

  if not found then
    raise exception
      'No active delivery pricing rule is configured for zone % and method %.'
      , p_delivery_zone_id, v_method
      using errcode='P0002';
  end if;

  v_base := v_rule.base_fee;

  if v_rule.pricing_model in ('distance','time_distance') then
    v_distance_fee := greatest(v_distance - v_rule.included_km, 0) * v_rule.per_km;
  end if;

  if v_rule.pricing_model = 'time_distance' then
    v_time_fee := greatest(v_minutes - v_rule.included_minutes, 0) * v_rule.per_minute;
  end if;

  if v_rule.peak_start is not null
     and v_rule.peak_end is not null
     and v_dow = any(v_rule.peak_days)
     and (
       (v_rule.peak_start <= v_rule.peak_end and v_t between v_rule.peak_start and v_rule.peak_end)
       or
       (v_rule.peak_start > v_rule.peak_end and (v_t >= v_rule.peak_start or v_t <= v_rule.peak_end))
     ) then
    v_peak := true;
    v_peak_fee :=
      greatest(v_base + v_distance_fee + v_time_fee, 0)
      * greatest(v_rule.peak_multiplier - 1, 0);
  end if;

  if v_rule.long_distance_threshold_km is not null
     and v_distance > v_rule.long_distance_threshold_km then
    v_long_fee := v_rule.long_distance_fee;
  end if;

  v_special_fee := v_rule.special_fee;
  v_raw := greatest(
    v_base + v_distance_fee + v_time_fee + v_peak_fee + v_long_fee + v_special_fee,
    0
  );

  v_total := round(v_raw / v_rule.rounding_increment) * v_rule.rounding_increment;
  v_total := greatest(v_total, v_rule.minimum_fee);

  return jsonb_build_object(
    'zone_id', p_delivery_zone_id,
    'zone_name', v_zone_name,
    'delivery_method', v_method,
    'pricing_rule_id', v_rule.id,
    'pricing_model', v_rule.pricing_model,
    'currency', v_rule.currency,
    'distance_km', round(v_distance, 3),
    'duration_minutes', case when p_duration_minutes is null then null else round(v_minutes, 2) end,
    'base_fee', v_base,
    'distance_fee', round(v_distance_fee, 2),
    'time_fee', round(v_time_fee, 2),
    'peak_fee', round(v_peak_fee, 2),
    'peak_applied', v_peak,
    'long_distance_fee', round(v_long_fee, 2),
    'special_fee', round(v_special_fee, 2),
    'minimum_fee', v_rule.minimum_fee,
    'delivery_fee', v_total,
    'effective_from', v_rule.effective_from,
    'effective_until', v_rule.effective_until
  );
end;
$function$;

revoke execute on function public.quote_delivery(uuid,numeric,numeric,text,timestamptz)
  from public, anon, authenticated;
grant execute on function public.quote_delivery(uuid,numeric,numeric,text,timestamptz)
  to anon, authenticated;

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
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_existing jsonb;
  v_created jsonb;
  v_order_id uuid;
  v_order_number text;
  v_subtotal numeric;
  v_quote jsonb;
  v_delivery_fee numeric;
  v_total numeric;
begin
  if p_idempotency_key is not null then
    select jsonb_build_object(
      'order_id',o.id,
      'order_number',o.order_number,
      'total',o.total,
      'idempotent',true
    )
    into v_existing
    from public.orders o
    where o.idempotency_key = p_idempotency_key;

    if v_existing is not null then
      return v_existing;
    end if;
  end if;

  if p_delivery_distance_km is null or p_delivery_distance_km < 0 then
    raise exception 'DELIVERY_DISTANCE_REQUIRED' using errcode='P0001';
  end if;

  v_quote := public.quote_delivery(
    p_delivery_zone_id,
    p_delivery_distance_km,
    p_delivery_duration_minutes,
    'default',
    now()
  );

  v_delivery_fee := (v_quote ->> 'delivery_fee')::numeric;

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

  v_order_id := (v_created ->> 'order_id')::uuid;

  if v_order_id is null then
    raise exception
      'CREATE_ORDER_FAILED: canonical create_order returned no order_id'
      using errcode='P0001';
  end if;

  if coalesce((v_created ->> 'idempotent')::boolean,false) then
    return v_created;
  end if;

  select subtotal, order_number
    into v_subtotal, v_order_number
  from public.orders
  where id = v_order_id
  for update;

  v_total := v_subtotal + v_delivery_fee;

  update public.orders
  set delivery_fee = v_delivery_fee,
      total = v_total,
      delivery_distance_km = round(p_delivery_distance_km,3),
      delivery_duration_minutes =
        case
          when p_delivery_duration_minutes is null then null
          else round(p_delivery_duration_minutes,2)
        end,
      delivery_origin_snapshot = p_delivery_origin,
      delivery_destination_snapshot = p_delivery_destination,
      delivery_method = 'default',
      delivery_pricing_rule_id = (v_quote ->> 'pricing_rule_id')::uuid,
      delivery_pricing_snapshot = v_quote
  where id = v_order_id;

  return jsonb_build_object(
    'order_id',v_order_id,
    'order_number',v_order_number,
    'subtotal',v_subtotal,
    'delivery_fee',v_delivery_fee,
    'total',v_total,
    'delivery_distance_km',round(p_delivery_distance_km,3),
    'delivery_duration_minutes',p_delivery_duration_minutes,
    'delivery_quote',v_quote,
    'idempotent',false
  );
end;
$function$;

revoke execute on function public.create_order(text,text,text,text,text,uuid,text,jsonb,text,numeric,numeric,jsonb,jsonb)
  from public, anon, authenticated;
grant execute on function public.create_order(text,text,text,text,text,uuid,text,jsonb,text,numeric,numeric,jsonb,jsonb)
  to anon, authenticated;
