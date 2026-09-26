-- Legacy track_order RPC kept for database compatibility.
-- The Flutter app now uses supabase/functions/track-order because the live
-- production schema stores the checkout phone as customer_phone_snapshot.
-- This definition is aligned with the current order_status_history columns.

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
  SELECT *
  INTO v_order
  FROM public.orders
  WHERE order_number = p_order_number
    AND right(regexp_replace(customer_phone_snapshot, '\\D', '', 'g'), 9)
        = right(regexp_replace(p_phone, '\\D', '', 'g'), 9);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'status', status,
        'note', note,
        'created_at', created_at
      )
      ORDER BY created_at
    ),
    '[]'::jsonb
  )
  INTO v_timeline
  FROM public.order_status_history
  WHERE order_id = v_order.id;

  SELECT jsonb_build_object(
    'id', s.id,
    'status', s.status,
    'courier_id', s.courier_id,
    'updated_at', s.updated_at
  )
  INTO v_shipment
  FROM public.shipments s
  WHERE s.order_id = v_order.id
  ORDER BY s.created_at DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'found', true,
    'order_id', v_order.id,
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
