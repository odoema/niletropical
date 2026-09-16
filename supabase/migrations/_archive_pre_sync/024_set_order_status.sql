-- 024_set_order_status.sql — admin wrapper for status changes
--
-- FIX (2026-09-11 pass 2): the prior version of this file inserted into
-- order_status_history (status, note) — the actual columns are
-- (to_status, notes) — AND it also duplicated the transition trigger
-- from 013_functions.sql, which already logs history on every valid
-- status change. Rewritten to (a) validate the caller is staff, (b)
-- update the status and let the trigger do the history insert + reject
-- illegal transitions, and (c) return the new status so the client can
-- refresh without re-querying.

CREATE OR REPLACE FUNCTION set_order_status(
  p_order_id uuid,
  p_status text,
  p_note text DEFAULT NULL   -- kept for signature compatibility; the trigger
                             -- writes changed_by = auth.uid(), so per-call
                             -- notes go straight on order_status_history
                             -- via the manual path below only.
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new order_status;
BEGIN
  -- Role gate. SECURITY DEFINER lets us bypass RLS, so a role check must
  -- live inside the function. sales / manager / super_admin can change
  -- order status — customers and couriers cannot.
  IF NOT (
    has_role('sales') OR has_role('manager') OR has_role('super_admin')
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: only sales/manager/super_admin may change order status'
      USING ERRCODE = '42501';
  END IF;

  -- Cast the incoming text to the enum. The trigger from 013 does its own
  -- validation of the transition (e.g. new → payment_pending is fine,
  -- processing → shipped is rejected).
  BEGIN
    v_new := p_status::order_status;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'INVALID_ORDER_STATUS: %', p_status USING ERRCODE = 'P0001';
  END;

  UPDATE orders SET status = v_new, updated_at = now() WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND: %' USING ERRCODE = 'P0002';
  END IF;

  -- Optional per-call note: append it to the history row the trigger just
  -- wrote (identified by the fact its notes column is still NULL for this
  -- transition on this order).
  IF p_note IS NOT NULL AND length(trim(p_note)) > 0 THEN
    UPDATE order_status_history
    SET notes = p_note
    WHERE order_id = p_order_id
      AND to_status = v_new
      AND notes IS NULL
      AND id = (
        SELECT id FROM order_status_history
        WHERE order_id = p_order_id AND to_status = v_new
        ORDER BY created_at DESC LIMIT 1
      );
  END IF;

  RETURN v_new::text;
END;
$$;

GRANT EXECUTE ON FUNCTION set_order_status(uuid, text, text) TO authenticated;

-- Drop the ambiguous admin_create_delivery_zone overload that this file
-- previously introduced. 019_admin_rpcs.sql (the fixed version) is the
-- canonical definition — signature: (p_name, p_delivery_fee, p_estimated_days,
-- p_notes).
DROP FUNCTION IF EXISTS admin_create_delivery_zone(text, numeric, text[]);
