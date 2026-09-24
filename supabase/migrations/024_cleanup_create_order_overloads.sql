-- 024_cleanup_create_order_overloads.sql
-- Production repair: remove legacy JSONB-address create_order overloads and
-- ensure the canonical text-address create_order contract exists.
--
-- This migration is intentionally self-contained so it can repair a database
-- where 016_create_order_v2.sql was not applied.

ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_email citext;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_idempotency
  ON orders (idempotency_key) WHERE idempotency_key IS NOT NULL;

DROP FUNCTION IF EXISTS public.create_order(
  text, text, text, text, jsonb, uuid, text, jsonb, text, text
);

DROP FUNCTION IF EXISTS public.create_order(
  text, text, text, text, jsonb, uuid, text, jsonb, text
);

DROP FUNCTION IF EXISTS public.create_order(
  text, text, text, text, text, uuid, text, jsonb, text
);

CREATE OR REPLACE FUNCTION create_order(
  p_idempotency_key text,
  p_full_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_delivery_zone_id uuid,
  p_payment_method text,
  p_items jsonb,
  p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
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
BEGIN
  -- Idempotency
  IF p_idempotency_key IS NOT NULL THEN
    SELECT jsonb_build_object(
      'order_id', o.id,
      'order_number', o.order_number,
      'total', o.total,
      'idempotent', true
    )
    INTO v_existing_json
    FROM orders o
    WHERE o.idempotency_key = p_idempotency_key;
    IF v_existing_json IS NOT NULL THEN
      RETURN v_existing_json;
    END IF;
  END IF;

  -- Validate the payment method against the schema enum. The client sends
  -- one of mtn_momo/airtel_money/card/cash_on_delivery (see 006_orders.sql).
  BEGIN
    v_payment_method := p_payment_method::payment_method;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: %', p_payment_method
      USING ERRCODE = 'P0001';
  END;

  v_initial_payment_status := CASE
    WHEN v_payment_method = 'cash_on_delivery' THEN 'unpaid'
    ELSE 'pending'
  END;

  -- Zone fee (server-authoritative, replaces any fee the client sent)
  SELECT COALESCE(delivery_fee, 0) INTO v_zone_fee
  FROM delivery_zones
  WHERE id = p_delivery_zone_id AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'INVALID_DELIVERY_ZONE: %', p_delivery_zone_id
      USING ERRCODE = 'P0002';
  END IF;

  -- Validate & price items server-side
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_variant FROM product_variants
    WHERE id = (v_item->>'variant_id')::uuid AND is_active = true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'INVALID_VARIANT: %', v_item->>'variant_id';
    END IF;
    IF v_variant.stock_quantity < (v_item->>'quantity')::int THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK: variant % has only % available',
        v_variant.id, v_variant.stock_quantity
        USING ERRCODE = 'P0003';
    END IF;
    v_subtotal := v_subtotal + v_variant.price * (v_item->>'quantity')::int;
  END LOOP;

  v_total := v_subtotal + v_zone_fee;
  v_order_number := generate_order_number();

  -- If the caller is an authenticated user whose auth.uid() maps to a
  -- customers row, wire orders.customer_id so account_orders_screen can
  -- filter by ID rather than the fragile customer_email hack. Guest
  -- checkout (no session or no linked customer) leaves customer_id NULL.
  DECLARE v_customer_id uuid;
  BEGIN
    SELECT id INTO v_customer_id FROM customers WHERE auth_user_id = auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_customer_id := NULL;
  END;

  INSERT INTO orders (
    order_number, status, payment_status, payment_method,
    subtotal, delivery_fee, discount_total, total,
    customer_id, customer_name, customer_phone, customer_email,
    delivery_zone_id, delivery_address, notes, idempotency_key
  ) VALUES (
    v_order_number, 'new', v_initial_payment_status, v_payment_method,
    v_subtotal, v_zone_fee, 0, v_total,
    v_customer_id, p_full_name, p_phone, p_email,
    p_delivery_zone_id, jsonb_build_object('line', p_address), p_notes, p_idempotency_key
  ) RETURNING id INTO v_order_id;

  -- Log initial status. The status-transition trigger from 013_functions.sql
  -- deliberately returns early on INSERT, so the first history row must be
  -- written explicitly here (with the correct columns: to_status, notes).
  INSERT INTO order_status_history (order_id, to_status, notes)
  VALUES (v_order_id, 'new', 'Order created');

  -- Write order_items with snapshot columns (schema uses *_snapshot names).
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_variant FROM product_variants WHERE id = (v_item->>'variant_id')::uuid;
    SELECT * INTO v_product  FROM products         WHERE id = v_variant.product_id;

    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name_snapshot, variant_name_snapshot, sku_snapshot,
      unit_price, quantity, line_total
    ) VALUES (
      v_order_id, v_variant.product_id, v_variant.id,
      v_product.name, v_variant.name, v_variant.sku,
      v_variant.price, (v_item->>'quantity')::int,
      v_variant.price * (v_item->>'quantity')::int
    );

    -- Deduct stock atomically via adjust_stock (row-lock, see 013).
    PERFORM adjust_stock(
      v_variant.id,
      -(v_item->>'quantity')::int,
      'sale'::stock_movement_type,
      v_order_number,
      NULL, NULL, NULL
    );
  END LOOP;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'total', v_total,
    'idempotent', false
  );
END;
$$;

-- Anon may call create_order via RPC for guest checkout (§35). The function
-- is SECURITY DEFINER so it can bypass RLS to write into orders/order_items
-- while enforcing its own price/stock/zone validation server-side.
GRANT EXECUTE ON FUNCTION create_order(text, text, text, text, text, uuid, text, jsonb, text)
  TO anon, authenticated;
