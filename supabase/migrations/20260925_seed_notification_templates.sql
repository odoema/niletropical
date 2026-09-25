-- Nile Tropical — production notification templates
-- Seeds the standard customer order lifecycle messages used by the admin
-- Notifications screen. Safe to re-run: existing event keys are updated.

insert into public.notification_templates
  (event_key, channel, template_body, is_active)
values
  (
    'order_received',
    'sms',
    'Nile Tropical: We have received your order {{order_number}}. Thank you for shopping with us.'
    , true
  ),
  (
    'order_confirmed',
    'sms',
    'Nile Tropical: Your order {{order_number}} has been confirmed and is being prepared.'
    , true
  ),
  (
    'payment_confirmed',
    'sms',
    'Nile Tropical: Payment for order {{order_number}} has been confirmed. We are preparing your items.'
    , true
  ),
  (
    'dispatched',
    'sms',
    'Nile Tropical: Your order {{order_number}} has been dispatched and is on its way.'
    , true
  ),
  (
    'out_for_delivery',
    'sms',
    'Nile Tropical: Your order {{order_number}} is now out for delivery.'
    , true
  ),
  (
    'delivered',
    'sms',
    'Nile Tropical: Your order {{order_number}} has been delivered. Thank you for shopping with us!'
    , true
  ),
  (
    'order_cancelled',
    'sms',
    'Nile Tropical: Your order {{order_number}} has been cancelled. Please contact us if you need assistance.'
    , true
  )
on conflict (event_key) do update
set
  channel = excluded.channel,
  template_body = excluded.template_body,
  is_active = excluded.is_active;
