-- Nile Tropical — live Supabase reconciliation 2026-09-27
-- This migration records fixes that were reconciled against the live
-- production project ououfhsswyqutcczdtnb. Do not use older archived
-- pricing/error-log migrations blindly; the live schema is authoritative.

-- Application error ingestion / admin diagnostics.
create table if not exists public.app_error_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  severity text not null default 'error'
    check (severity in ('info','warning','error','fatal')),
  source text not null default 'flutter',
  error_code text,
  message text not null,
  technical_message text,
  stack_trace text,
  route text,
  action text,
  fingerprint text,
  context jsonb not null default '{}'::jsonb,
  user_id uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  resolution_note text
);

create index if not exists idx_app_error_logs_created_at
  on public.app_error_logs(created_at desc);
create index if not exists idx_app_error_logs_severity
  on public.app_error_logs(severity);
create index if not exists idx_app_error_logs_source
  on public.app_error_logs(source);
create index if not exists idx_app_error_logs_fingerprint
  on public.app_error_logs(fingerprint);
create index if not exists idx_app_error_logs_unresolved
  on public.app_error_logs(created_at desc)
  where resolved_at is null;

alter table public.app_error_logs enable row level security;
revoke all on public.app_error_logs from anon;
revoke all on public.app_error_logs from authenticated;
grant select, update on public.app_error_logs to authenticated;

drop policy if exists app_error_logs_staff_read on public.app_error_logs;
create policy app_error_logs_staff_read on public.app_error_logs
for select to authenticated
using ((select has_role('manager')) or (select has_role('finance')) or (select has_role('super_admin')));

drop policy if exists app_error_logs_staff_update on public.app_error_logs;
create policy app_error_logs_staff_update on public.app_error_logs
for update to authenticated
using ((select has_role('manager')) or (select has_role('finance')) or (select has_role('super_admin')))
with check ((select has_role('manager')) or (select has_role('finance')) or (select has_role('super_admin')));

create or replace function public.record_app_error(
  p_severity text,
  p_source text,
  p_error_code text default null,
  p_message text default 'Application error',
  p_technical_message text default null,
  p_stack_trace text default null,
  p_route text default null,
  p_action text default null,
  p_fingerprint text default null,
  p_context jsonb default '{}'::jsonb
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare
  v_id uuid;
  v_severity text;
begin
  v_severity := case lower(coalesce(p_severity,'error'))
    when 'info' then 'info'
    when 'warning' then 'warning'
    when 'fatal' then 'fatal'
    else 'error'
  end;

  insert into public.app_error_logs(
    severity,source,error_code,message,technical_message,stack_trace,
    route,action,fingerprint,context,user_id
  )
  values(
    v_severity,
    left(coalesce(nullif(btrim(p_source),''),'flutter'),80),
    left(nullif(btrim(p_error_code),''),120),
    left(coalesce(nullif(btrim(p_message),''),'Application error'),500),
    left(nullif(p_technical_message,''),4000),
    left(nullif(p_stack_trace,''),12000),
    left(nullif(p_route,''),500),
    left(nullif(p_action,''),200),
    left(nullif(p_fingerprint,''),128),
    case when jsonb_typeof(coalesce(p_context,'{}'::jsonb))='object'
      then coalesce(p_context,'{}'::jsonb) else '{}'::jsonb end,
    (select auth.uid())
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.record_app_error(text,text,text,text,text,text,text,text,text,jsonb) from public;
grant execute on function public.record_app_error(text,text,text,text,text,text,text,text,text,jsonb) to anon, authenticated;

-- Pricing reconciliation: the live table uses variant_id + suggested_retail_price.
create or replace function public.apply_pricing_recommendation(p_recommendation_id uuid)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  rec record;
  old_price numeric;
  new_price numeric;
begin
  if not (has_role('manager') or has_role('finance') or has_role('super_admin')) then
    raise exception 'Not authorised to apply pricing recommendations';
  end if;

  select id, variant_id, suggested_retail_price
    into rec
  from public.pricing_recommendations
  where id=p_recommendation_id
  for update;

  if rec.id is null then raise exception 'Pricing recommendation not found'; end if;
  if rec.suggested_retail_price is null or rec.suggested_retail_price <= 0 then
    raise exception 'Pricing recommendation has an invalid suggested retail price';
  end if;

  select price into old_price
  from public.product_variants
  where id=rec.variant_id
  for update;

  if old_price is null then raise exception 'Product variant not found'; end if;

  new_price := rec.suggested_retail_price;

  update public.product_variants set price=new_price where id=rec.variant_id;

  update public.pricing_recommendations
  set status='approved', approved_by=auth.uid(), approved_at=now(), updated_at=now()
  where id=rec.id;

  insert into public.audit_logs(
    user_id,action,entity_type,entity_id,previous_data,new_data
  )
  values(
    auth.uid(),'product.price_changed','product_variants',rec.variant_id::text,
    jsonb_build_object('price',old_price,'pricing_recommendation_id',rec.id),
    jsonb_build_object('price',new_price,'pricing_recommendation_id',rec.id)
  );

  return jsonb_build_object(
    'recommendation_id',rec.id,
    'product_variant_id',rec.variant_id,
    'old_price',old_price,
    'new_price',new_price,
    'status','approved'
  );
end;
$$;

revoke all on function public.apply_pricing_recommendation(uuid) from public;
grant execute on function public.apply_pricing_recommendation(uuid) to authenticated;
