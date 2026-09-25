-- 20260925_pricing_apply_audit.sql
-- Atomically apply a pricing recommendation to the live catalogue and
-- record the change using the production audit_logs schema.

create or replace function public.apply_pricing_recommendation(
  p_recommendation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  old_price numeric;
  new_price numeric;
begin
  if not (
    has_role('manager')
    or has_role('finance')
    or has_role('super_admin')
  ) then
    raise exception 'Not authorised to apply pricing recommendations';
  end if;

  select id, product_variant_id, recommended_price
  into rec
  from public.pricing_recommendations
  where id = p_recommendation_id
  for update;

  if rec.id is null then
    raise exception 'Pricing recommendation not found';
  end if;

  if rec.product_variant_id is null then
    raise exception 'Pricing recommendation is not linked to a product variant';
  end if;

  if rec.recommended_price is null or rec.recommended_price <= 0 then
    raise exception 'Pricing recommendation has an invalid recommended price';
  end if;

  select price
  into old_price
  from public.product_variants
  where id = rec.product_variant_id
  for update;

  if old_price is null then
    raise exception 'Product variant not found';
  end if;

  new_price := rec.recommended_price;

  update public.product_variants
  set price = new_price
  where id = rec.product_variant_id;

  update public.pricing_recommendations
  set status = 'approved',
      current_price = new_price
  where id = rec.id;

  insert into public.audit_logs (
    user_id,
    action,
    entity_type,
    entity_id,
    previous_data,
    new_data
  )
  values (
    auth.uid(),
    'product.price_changed',
    'product_variants',
    rec.product_variant_id::text,
    jsonb_build_object(
      'price', old_price,
      'pricing_recommendation_id', rec.id
    ),
    jsonb_build_object(
      'price', new_price,
      'pricing_recommendation_id', rec.id
    )
  );

  return jsonb_build_object(
    'recommendation_id', rec.id,
    'product_variant_id', rec.product_variant_id,
    'old_price', old_price,
    'new_price', new_price,
    'status', 'approved'
  );
end;
$$;

revoke all on function public.apply_pricing_recommendation(uuid) from public;
grant execute on function public.apply_pricing_recommendation(uuid) to authenticated;

grant insert on public.audit_logs to authenticated;

drop policy if exists audit_logs_staff_insert on public.audit_logs;

create policy audit_logs_staff_insert
on public.audit_logs
for insert
to authenticated
with check (user_id = auth.uid());
