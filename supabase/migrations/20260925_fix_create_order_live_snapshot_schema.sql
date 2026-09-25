-- Nile Tropical — repair create_order against the live orders snapshot schema.
-- The production orders table uses customer_name_snapshot,
-- customer_phone_snapshot and delivery_address_snapshot.
-- It also links authenticated customers through customers.user_id.

create or replace function public.create_order(
  p_idempotency_key text,
  p_full_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_delivery_zone_id uuid,
  p_payment_method text,
  p_items jsonb,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing_json jsonb;
  v_order_id uuid;
  v_order_number text;
  v_zone_fee numeric := 0;
  v_subtotal numeric := 0;
  v_total numeric := 0;
  v_item jsonb;
  v_variant record;
  v_product record;
  v_payment_method payment_method;
  v_initial_payment_status payment_status;
  v_initial_order_status text;
  v_customer_id uuid;
begin
  if p_idempotency_key is not null then
    select jsonb_build_object(
      'order_id', o.id,
      'order_number', o.order_number,
      'total', o.total,
      'idempotent', true
    )
    into v_existing_json
    from public.orders o
    where o.idempotency_key = p_idempotency_key;

    if v_existing_json is not null then
      return v_existing_json;
    end if;
  end if;

  begin
    v_payment_method := p_payment_method::payment_method;
  exception when invalid_text_representation then
    raise exception 'INVALID_PAYMENT_METHOD: %', p_payment_method
      using errcode = 'P0001';
  end;

  v_initial_payment_status := case
    when v_payment_method = 'cash_on_delivery' then 'unpaid'
    else 'pending'
  end;

  -- Non-COD orders must enter the payment-pending state so the payment
  -- gateway can accept them. COD orders remain new_order for staff fulfilment.
  v_initial_order_status := case
    when v_payment_method = 'cash_on_delivery' then 'new_order'
    else 'payment_pending'
  end;

  select coalesce(delivery_fee, 0)
    into v_zone_fee
  from public.delivery_zones
  where id = p_delivery_zone_id
    and is_active = true;

  if not found then
    raise exception 'INVALID_DELIVERY_ZONE: %', p_delivery_zone_id
      using errcode = 'P0002';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into v_variant
    from public.product_variants
    where id = (v_item->>'variant_id')::uuid
      and is_active = true;

    if not found then
      raise exception 'INVALID_VARIANT: %', v_item->>'variant_id';
    end if;

    if v_variant.stock_quantity < (v_item->>'quantity')::int then
      raise exception 'INSUFFICIENT_STOCK: variant % has only % available',
        v_variant.id, v_variant.stock_quantity
        using errcode = 'P0003';
    end if;

    v_subtotal := v_subtotal +
      v_variant.price * (v_item->>'quantity')::int;
  end loop;

  v_total := v_subtotal + v_zone_fee;
  v_order_number := public.generate_order_number();

  -- Authenticated Google/customer users use the canonical customers.user_id
  -- ownership chain. Guests remain customer_id NULL.
  begin
    select c.id
      into v_customer_id
    from public.customers c
    where c.user_id = auth.uid()
    order by c.created_at asc
    limit 1;
  exception when others then
    v_customer_id := null;
  end;

  insert into public.orders (
    order_number,
    status,
    payment_status,
    payment_method,
    subtotal,
    delivery_fee,
    discount_total,
    total,
    customer_id,
    customer_name_snapshot,
    customer_phone_snapshot,
    customer_email,
    delivery_zone_id,
    delivery_address_snapshot,
    notes,
    idempotency_key
  ) values (
    v_order_number,
    v_initial_order_status,
    v_initial_payment_status,
    v_payment_method,
    v_subtotal,
    v_zone_fee,
    0,
    v_total,
    v_customer_id,
    p_full_name,
    p_phone,
    p_email,
    p_delivery_zone_id,
    jsonb_build_object('address_line', p_address),
    p_notes,
    p_idempotency_key
  )
  returning id into v_order_id;

  insert into public.order_status_history (
    order_id,
    to_status,
    notes
  ) values (
    v_order_id,
    v_initial_order_status,
    'Order created'
  );

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into v_variant
    from public.product_variants
    where id = (v_item->>'variant_id')::uuid;

    select * into v_product
    from public.products
    where id = v_variant.product_id;

    insert into public.order_items (
      order_id,
      product_id,
      variant_id,
      product_name_snapshot,
      variant_name_snapshot,
      sku_snapshot,
      unit_price,
      quantity,
      line_total
    ) values (
      v_order_id,
      v_variant.product_id,
      v_variant.id,
      v_product.name,
      v_variant.name,
      v_variant.sku,
      v_variant.price,
      (v_item->>'quantity')::int,
      v_variant.price * (v_item->>'quantity')::int
    );

    perform public.adjust_stock(
      v_variant.id,
      -(v_item->>'quantity')::int,
      'sale'::stock_movement_type,
      v_order_number,
      null,
      null,
      null
    );
  end loop;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'total', v_total,
    'idempotent', false
  );
end;
$$;

grant execute on function public.create_order(
  text, text, text, text, text, uuid, text, jsonb, text
) to anon, authenticated;
