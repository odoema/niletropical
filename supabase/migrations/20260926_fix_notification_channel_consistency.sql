-- Nile Tropical — notification channel consistency
-- 2026-09-26
--
-- Canonical notification architecture:
--   push  -> scheduled Web Push dispatcher
--   email -> Resend via notification-dispatch
--   sms   -> not configured; never enqueue new SMS records
--   whatsapp -> reserved for future integration
--
-- Existing legacy SMS rows are preserved for audit but marked failed
-- because there is no SMS provider behind them.

-- Preserve legacy records but make their terminal state explicit.
UPDATE public.notification_logs
SET
  status = 'failed',
  provider = 'legacy_sms',
  error_message = COALESCE(
    error_message,
    'Legacy SMS notification retained for audit; SMS provider is not configured.'
  )
WHERE channel = 'sms'
  AND status IN ('pending', 'processing');

-- Canonical lifecycle trigger:
-- queue Web Push records only. Payment confirmation email is sent
-- by payment-status through notification-dispatch/Resend.
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

  -- Web Push is the only queued lifecycle channel currently
  -- supported by the background dispatcher.
  PERFORM public.queue_order_notification(
    NEW.id,
    NEW.customer_phone_snapshot,
    'push',
    v_event,
    v_fallback
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enqueue_order_lifecycle_notification
ON public.orders;

CREATE TRIGGER enqueue_order_lifecycle_notification
AFTER INSERT OR UPDATE OF status, payment_status
ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.enqueue_order_lifecycle_notification();

COMMENT ON FUNCTION public.enqueue_order_lifecycle_notification()
IS
'Queues Web Push lifecycle events. Payment confirmation email is handled directly by payment-status through notification-dispatch/Resend. SMS is intentionally not queued until an SMS provider is configured.';
