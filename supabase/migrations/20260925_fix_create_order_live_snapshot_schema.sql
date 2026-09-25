-- Nile Tropical — production create_order repair.
-- Aligned to the live production schema inspected on 2026-09-25.
-- Non-COD orders start in payment_pending so payment initiation can proceed.
-- COD orders start in new_order and never require gateway payment.

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
)
returns jsonb
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

  v_customer_id uuid;
  v_payment_status text;
  v_order_status text;
  v_quantity integer;
  v_remaining_stock integer;

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

  if lower(p_payment_method) = 'cash_on_delivery' then
    v_payment_status := 'unpaid';
    v_order_status := 'new_order';
  else
    v_payment_status := 'pending';
    v_order_status := 'payment_pending';
  end if;

  select coalesce(delivery_fee, 0)
  into v_zone_fee
  from public.delivery_zones
  where id = p_delivery_zone_id
    and is_active = true;

  if not found then
    raise exception
      'INVALID_DELIVERY_ZONE: %',
      p_delivery_zone_id
      using errcode = 'P0002';
  end if;

  for v_item in
    select *
    from jsonb_array_elements(p_items)
  loop

    v_quantity := (v_item->>'quantity')::integer;

    if v_quantity is null or v_quantity <= 0 then
      raise exception
        'INVALID_QUANTITY: %',
        v_item->>'quantity';
    end if;

    select *
    into v_variant
    from public.product_variants
    where id = (v_item->>'variant_id')::uuid
      and is_active = true;

    if not found then
      raise exception
        'INVALID_VARIANT: %',
        v_item->>'variant_id';
    end if;

    if v_variant.stock_quantity < v_quantity then
      raise exception
        'INSUFFICIENT_STOCK: variant % has only % available',
        v_variant.id,
        v_variant.stock_quantity
        using errcode = 'P0003';
    end if;

    v_subtotal :=
      v_subtotal +
      v_variant.price * v_quantity;

  end loop;

  v_total := v_subtotal + v_zone_fee;

  v_order_number :=
    public.generate_order_number();

  begin
    select c.id
    into v_customer_id
    from public.customers c
    where c.user_id = auth.uid()
    order by c.created_at asc
    limit 1;
  exception
    when others then
      v_customer_id := null;
  end;

  insert into public.orders (
    order_number,
    status,
    payment_status,
    payment_method,
    currency,
    subtotal,
    delivery_fee,
    discount_total,
    total,
    customer_id,
    customer_name_snapshot,
    customer_phone_snapshot,
    customer_email_snapshot,
    delivery_address_snapshot,
    notes,
    idempotency_key
  )
  values (
    v_order_number,
    v_order_status,
    v_payment_status,
    p_payment_method,
    'UGX',
    v_subtotal,
    v_zone_fee,
    0,
    v_total,
    v_customer_id,
    p_full_name,
    p_phone,
    p_email,
    jsonb_build_object(
      'address_line',
      p_address
    ),
    p_notes,
    p_idempotency_key
  )
  returning id
  into v_order_id;

  insert into public.order_status_history (
    order_id,
    status,
    note
  )
  values (
    v_order_id,
    v_order_status,
    'Order created'
  );

  for v_item in
    select *
    from jsonb_array_elements(p_items)
  loop

    v_quantity := (v_item->>'quantity')::integer;

    select *
    into v_variant
    from public.product_variants
    where id = (v_item->>'variant_id')::uuid;

    select *
    into v_product
    from public.products
    where id = v_variant.product_id;

    insert into public.order_items (
      order_id,
      product_variant_id,
      product_name_snapshot,
      variant_name_snapshot,
      sku_snapshot,
      unit_price,
      discount,
      quantity,
      line_total
    )
    values (
      v_order_id,
      v_variant.id,
      v_product.name,
      v_variant.name,
      v_variant.sku,
      v_variant.price,
      0,
      v_quantity,
      v_variant.price * v_quantity
    );

    update public.product_variants
    set
      stock_quantity = stock_quantity - v_quantity,
      updated_at = now()
    where id = v_variant.id
      and is_active = true
      and stock_quantity >= v_quantity
    returning stock_quantity
    into v_remaining_stock;

    if not found then
      raise exception
        'INSUFFICIENT_STOCK: variant % no longer has % units available',
        v_variant.id,
        v_quantity
        using errcode = 'P0003';
    end if;

    insert into public.stock_movements (
      product_variant_id,
      movement_type,
      quantity,
      reference,
      notes,
      created_by
    )
    values (
      v_variant.id,
      'sale',
      -v_quantity,
      v_order_number,
      'Stock deducted for customer order',
      auth.uid()
    );

  end loop;

  return jsonb_build_object(
    'order_id',
    v_order_id,
    'order_number',
    v_order_number,
    'total',
    v_total,
    'idempotent',
    false
  );

end;
$$;

grant execute on function public.create_order(
  text,
  text,
  text,
  text,
  text,
  uuid,
  text,
  jsonb,
  text
)
to anon, authenticated;
