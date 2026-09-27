-- Nile Tropical — geographic delivery-zone reconciliation
-- Repository migration only. Do not apply to production until zone geometry/data
-- is reviewed and approved.
--
-- KEEP existing zone names/fees. These nullable fields add geographic metadata
-- without inventing coordinates or changing current pricing.

alter table public.delivery_zones
  add column if not exists center_latitude numeric(9,6),
  add column if not exists center_longitude numeric(9,6),
  add column if not exists radius_km numeric(8,2);

alter table public.delivery_zones
  add constraint delivery_zones_center_latitude_chk
    check (center_latitude is null or center_latitude between -90 and 90),
  add constraint delivery_zones_center_longitude_chk
    check (center_longitude is null or center_longitude between -180 and 180),
  add constraint delivery_zones_radius_km_chk
    check (radius_km is null or radius_km > 0);

create index if not exists idx_delivery_zones_active_geo
  on public.delivery_zones (is_active, center_latitude, center_longitude)
  where is_active = true
    and center_latitude is not null
    and center_longitude is not null;

create or replace function public.resolve_delivery_zone(
  p_latitude numeric,
  p_longitude numeric
)
returns table (
  zone_id uuid,
  zone_name text,
  distance_km numeric
)
language sql
stable
set search_path = public
as $$
  with candidates as (
    select
      z.id,
      z.name,
      z.radius_km,
      6371.0088 * 2 * asin(
        sqrt(
          power(sin(radians(p_latitude - z.center_latitude) / 2), 2)
          + cos(radians(z.center_latitude))
          * cos(radians(p_latitude))
          * power(sin(radians(p_longitude - z.center_longitude) / 2), 2)
        )
      ) as distance_km
    from public.delivery_zones z
    where z.is_active = true
      and z.center_latitude is not null
      and z.center_longitude is not null
      and z.radius_km is not null
  )
  select
    id as zone_id,
    name as zone_name,
    round(distance_km::numeric, 2) as distance_km
  from candidates
  where distance_km <= radius_km
  order by distance_km asc
  limit 1;
$$;

revoke all on function public.resolve_delivery_zone(numeric, numeric) from public;
grant execute on function public.resolve_delivery_zone(numeric, numeric) to anon, authenticated, service_role;

comment on function public.resolve_delivery_zone(numeric, numeric)
is 'Returns the nearest active delivery zone whose configured radius contains the supplied coordinates. Does not invent or alter zone pricing.';
