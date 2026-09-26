-- Nile Tropical: SafeBoda-like distance pricing
-- Apply this in the PRODUCTION Nile Tropical Supabase SQL Editor.
-- Pricing model: UGX 2,500 base + UGX 450 per road kilometre.
-- Service zones remain for service coverage/eligibility; their stored
-- delivery_fee values are no longer used by quote_delivery().

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
  v_zone_name text;
  v_distance_km numeric := greatest(coalesce(p_distance_km, 0), 0);
  v_base_fee numeric := 2500;
  v_per_km_rate numeric := 450;
  v_delivery_fee numeric;
begin
  select dz.name
    into v_zone_name
  from public.delivery_zones dz
  where dz.id = p_delivery_zone_id
    and dz.is_active = true;

  if v_zone_name is null then
    raise exception 'Delivery zone is not active or does not exist.';
  end if;

  v_delivery_fee := round(v_base_fee + (v_distance_km * v_per_km_rate), 0);

  return jsonb_build_object(
    'zone_id', p_delivery_zone_id,
    'zone_name', v_zone_name,
    'distance_km', round(v_distance_km, 2),
    'included_km', 0,
    'extra_km_units', 0,
    'base_fee', v_base_fee,
    'extra_km_rate', v_per_km_rate,
    'delivery_fee', v_delivery_fee,
    'pricing_model', 'safeboda_like',
    'currency', 'UGX'
  );
end;
$$;

-- Keep the existing RPC callable by the application roles.
grant execute on function public.quote_delivery(uuid, numeric) to anon, authenticated;

-- Verification: expected fees are 2,500; 3,400; 4,750; 7,000
-- for 0 km, 2 km, 5 km, and 10 km respectively.
select
  d.km,
  (public.quote_delivery(
    (select id from public.delivery_zones where is_active = true order by name limit 1),
    d.km
  )->>'delivery_fee')::numeric as delivery_fee
from (values (0::numeric), (2::numeric), (5::numeric), (10::numeric)) as d(km);
