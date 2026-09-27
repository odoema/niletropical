-- Reconciliation-only notification trigger repair.
-- The live trigger currently sends lifecycle notifications through
-- queue_order_notification(..., 'push', ...), which records the phone number
-- as a push recipient and bypasses the push-subscription guard.
-- Use the dedicated push helper instead.
-- DO NOT DEPLOY until notification regression tests pass.

CREATE OR REPLACE FUNCTION public.enqueue_order_lifecycle_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event text;
  v_fallback text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_event := 'order_received';
    v_fallback :=
      'Nile Tropical: We have received your order ' ||
      NEW.order_number ||
      '. Thank you for shopping with us.';

  ELSIF NEW.payment_status IS DISTINCT FROM OLD.payment_status
        AND NEW.payment_status = 'paid' THEN
    v_event := 'payment_confirmed';
    v_fallback :=
      'Nile Tropical: Payment for order ' ||
      NEW.order_number ||
      ' has been confirmed. We are preparing your items.';

  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    v_event := CASE NEW.status::text
      WHEN 'order_confirmed' THEN 'order_confirmed'
      WHEN 'dispatched' THEN 'dispatched'
      WHEN 'out_for_delivery' THEN 'out_for_delivery'
      WHEN 'delivered' THEN 'delivered'
      WHEN 'cancelled' THEN 'order_cancelled'
      ELSE NULL
    END;

    IF v_event IS NULL THEN
      RETURN NEW;
    END IF;

    v_fallback := CASE v_event
      WHEN 'order_confirmed' THEN
        'Nile Tropical: Your order ' || NEW.order_number ||
        ' has been confirmed and is being prepared.'
      WHEN 'dispatched' THEN
        'Nile Tropical: Your order ' || NEW.order_number ||
        ' has been dispatched and is on its way.'
      WHEN 'out_for_delivery' THEN
        'Nile Tropical: Your order ' || NEW.order_number ||
        ' is now out for delivery.'
      WHEN 'delivered' THEN
        'Nile Tropical: Your order ' || NEW.order_number ||
        ' has been delivered. Thank you for shopping with us!'
      WHEN 'order_cancelled' THEN
        'Nile Tropical: Your order ' || NEW.order_number ||
        ' has been cancelled. Please contact us if you need assistance.'
      ELSE NULL
    END;

  ELSE
    RETURN NEW;
  END IF;

  -- Use the dedicated push helper so guest orders and users without a
  -- registered push subscription do not create bogus push log records.
  PERFORM public.queue_order_push_notification(
    NEW.id,
    v_event,
    v_fallback
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.enqueue_order_lifecycle_notification()
IS
'Queues lifecycle events through the dedicated Web Push helper. Payment confirmation email is handled by payment-status through notification-dispatch/Resend. SMS is intentionally not queued until an SMS provider is configured.';
