-- 017_stock_v2.sql — record_stock_movement wrapper around adjust_stock
--
-- FIX (2026-09-11): the prior version tried to insert into stock_movements
-- with columns (quantity_delta, reason, reference_id, note) that do not
-- exist — the schema in 004_inventory.sql uses (quantity, movement_type,
-- reference, notes). It also introduced a second unlocked write path that
-- could race against adjust_stock. Rewritten as a thin wrapper around the
-- concurrency-safe adjust_stock from 013_functions.sql. The warehouse_stock
-- table from 015 is now optional bookkeeping — it is updated when a row
-- exists, and silently skipped otherwise so the main stock path is never
-- blocked by a missing warehouse row.

CREATE OR REPLACE FUNCTION record_stock_movement(
  p_variant_id uuid,
  p_delta integer,
  p_reason text,                 -- must match stock_movement_type
  p_reference_id uuid DEFAULT NULL, -- unused; kept for source compatibility
  p_note text DEFAULT NULL,
  p_warehouse_id uuid DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wh uuid;
  v_new_stock int;
  v_movement_type stock_movement_type;
BEGIN
  -- Cast reason into the schema enum
  BEGIN
    v_movement_type := p_reason::stock_movement_type;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'INVALID_MOVEMENT_TYPE: %', p_reason;
  END;

  -- Delegate to the row-locked, transactionally safe path (013_functions.sql)
  SELECT new_stock_quantity INTO v_new_stock
  FROM adjust_stock(
    p_variant_id,
    p_delta,
    v_movement_type,
    NULL,   -- reference (optional; the main path uses order number in 016)
    p_note,
    NULL,   -- batch_id
    NULL    -- created_by
  );

  -- Optional per-warehouse cache maintenance. Non-blocking: if warehouse
  -- infra from 015 exists AND there is a default warehouse AND there is
  -- already a row for this variant, keep it in sync. Otherwise skip — the
  -- product_variants.stock_quantity above is the source of truth.
  IF p_warehouse_id IS NULL THEN
    SELECT id INTO v_wh FROM warehouses WHERE is_default = true LIMIT 1;
  ELSE
    v_wh := p_warehouse_id;
  END IF;

  IF v_wh IS NOT NULL THEN
    UPDATE warehouse_stock
    SET quantity   = GREATEST(0, quantity + p_delta),
        updated_at = now()
    WHERE warehouse_id = v_wh
      AND product_variant_id = p_variant_id;
  END IF;

  RETURN v_new_stock;
END;
$$;

GRANT EXECUTE ON FUNCTION record_stock_movement(uuid, integer, text, uuid, text, uuid)
  TO authenticated;
