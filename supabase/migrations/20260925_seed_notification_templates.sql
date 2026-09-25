-- Nile Tropical — production notification templates
-- Matches the existing production notification_templates schema.

insert into public.notification_templates
  (event_key, channel, body_template, is_active)
values
  ('order_received', 'sms', 'Nile Tropical: We have received your order {{order_number}}. Thank you for shopping with us.', true),
  ('order_confirmed', 'sms', 'Nile Tropical: Your order {{order_number}} has been confirmed and is being prepared.', true),
  ('payment_confirmed', 'sms', 'Nile Tropical: Payment for order {{order_number}} has been confirmed. We are preparing your items.', true),
  ('dispatched', 'sms', 'Nile Tropical: Your order {{order_number}} has been dispatched and is on its way.', true),
  ('out_for_delivery', 'sms', 'Nile Tropical: Your order {{order_number}} is now out for delivery.', true),
  ('delivered', 'sms', 'Nile Tropical: Your order {{order_number}} has been delivered. Thank you for shopping with us!', true),
  ('order_cancelled', 'sms', 'Nile Tropical: Your order {{order_number}} has been cancelled. Please contact us if you need assistance.', true)
on conflict (event_key) do update
set
  channel = excluded.channel,
  body_template = excluded.body_template,
  is_active = excluded.is_active,
  updated_at = now();
