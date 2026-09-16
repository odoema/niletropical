-- 018_track_order.sql — public tracking by order number + phone (§22)
--
-- FIX (2026-09-11): read order_status_history.status/note; actual columns
-- are to_status/notes. The Dart client (order_service.dart.trackOrder)
-- expects a jsonb map with a `timeline` array whose entries carry the
-- `status`/`note` keys, so those legacy keys are kept in the projection
-- while the underlying reads use the real column names.
--
-- Also replaces the earlier duplicate definition at the bottom of
-- 014_rls.sql (which returned TABLE(...)); the Dart client expects jsonb.

CREATE OR REPLACE FUNCTION track_order(
  p_order_number text,
  p_phone text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_timeline jsonb;
  v_shipment jsonb;
BEGIN
  -- Match on last 9 digits of the phone (Uganda mobile numbers) so
  -- different formats — +256777xxx, 0777xxx, 256777xxx — all resolve
  -- to the same customer.
  SELECT * INTO v_order FROM orders
  WHERE order_number = p_order_number
    AND right(regexp_replace(customer_phone, '\D', '', 'g'), 9)
        = right(regexp_replace(p_phone, '\D', '', 'g'), 9);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'status', to_status,
      'note', notes,
      'created_at', created_at
    ) ORDER BY created_at
  ), '[]'::jsonb)
  INTO v_timeline
  FROM order_status_history WHERE order_id = v_order.id;

  SELECT jsonb_build_object(
    'id', s.id,
    'status', s.status,
    'courier_id', s.courier_id,
    'updated_at', s.updated_at
  ) INTO v_shipment
  FROM shipments s WHERE s.order_id = v_order.id
  ORDER BY s.created_at DESC LIMIT 1;

  RETURN jsonb_build_object(
    'found', true,
    'order_number', v_order.order_number,
    'status', v_order.status,
    'payment_status', v_order.payment_status,
    'total', v_order.total,
    'created_at', v_order.created_at,
    'timeline', v_timeline,
    'shipment', v_shipment
  );
END;
$$;

GRANT EXECUTE ON FUNCTION track_order(text, text) TO anon, authenticated;
