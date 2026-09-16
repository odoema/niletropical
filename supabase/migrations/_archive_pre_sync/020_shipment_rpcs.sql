-- 020_shipment_rpcs.sql — create / assign / status / POD (§28–29)
--
-- FIX (2026-09-11): the prior version inserted `warehouse_id` into
-- shipments (no such column) and wrote POD fields onto `shipments` — the
-- shipments table has no `pod_photo_url`/`pod_recipient_name`/`pod_notes`/
-- `cod_collected`. Those fields belong on the dedicated `proof_of_delivery`
-- table (see 008_delivery.sql). Rewritten accordingly.

CREATE OR REPLACE FUNCTION create_shipment(
  p_order_id uuid,
  p_delivery_partner_id uuid DEFAULT NULL,
  p_courier_id uuid DEFAULT NULL,
  p_tracking_reference text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO shipments (
    order_id, delivery_partner_id, courier_id, tracking_reference, status
  )
  VALUES (
    p_order_id, p_delivery_partner_id, p_courier_id, p_tracking_reference, 'pending'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION assign_shipment(
  p_shipment_id uuid,
  p_courier_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE shipments
  SET courier_id = p_courier_id,
      status     = 'assigned',
      updated_at = now()
  WHERE id = p_shipment_id;
END;
$$;

-- update_shipment_status: propagates certain shipment statuses to the
-- parent order via the concurrency-safe order UPDATE (the transition trigger
-- from 013_functions.sql will reject illegal jumps and append history).
CREATE OR REPLACE FUNCTION update_shipment_status(
  p_shipment_id uuid,
  p_status text,
  p_note text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_order uuid;
BEGIN
  UPDATE shipments
  SET status = p_status, updated_at = now()
  WHERE id = p_shipment_id
  RETURNING order_id INTO v_order;

  IF p_status = 'delivered' THEN
    UPDATE orders SET status = 'delivered', updated_at = now() WHERE id = v_order;
  ELSIF p_status = 'out_for_delivery' THEN
    UPDATE orders SET status = 'out_for_delivery', updated_at = now() WHERE id = v_order;
  END IF;
END;
$$;

-- submit_proof_of_delivery: inserts into the dedicated proof_of_delivery
-- table (schema in 008_delivery.sql) rather than trying to write POD
-- columns to shipments. Also updates the shipment's delivered_at and the
-- parent order's status/payment_status (COD is settled here).
CREATE OR REPLACE FUNCTION submit_proof_of_delivery(
  p_shipment_id uuid,
  p_photo_storage_path text,
  p_recipient_name text DEFAULT NULL,
  p_otp_or_signature text DEFAULT NULL,
  p_location text DEFAULT NULL,
  p_cod_collected numeric DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pod_id uuid;
  v_order  uuid;
  v_courier uuid;
BEGIN
  SELECT order_id, courier_id INTO v_order, v_courier
  FROM shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SHIPMENT_NOT_FOUND: %', p_shipment_id;
  END IF;

  INSERT INTO proof_of_delivery (
    shipment_id, courier_id, recipient_name, otp_or_signature,
    photo_storage_path, location, cod_amount_collected
  ) VALUES (
    p_shipment_id, v_courier, p_recipient_name, p_otp_or_signature,
    p_photo_storage_path, p_location, p_cod_collected
  ) RETURNING id INTO v_pod_id;

  UPDATE shipments
  SET status       = 'delivered',
      delivered_at = now(),
      updated_at   = now()
  WHERE id = p_shipment_id;

  UPDATE orders
  SET status         = 'delivered',
      payment_status = CASE
        WHEN p_cod_collected IS NOT NULL THEN 'paid'::payment_status
        ELSE payment_status
      END,
      updated_at = now()
  WHERE id = v_order;

  RETURN v_pod_id;
END;
$$;
