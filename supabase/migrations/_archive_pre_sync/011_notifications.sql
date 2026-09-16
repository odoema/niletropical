-- Nile Tropical Uganda — 011_notifications.sql
-- Matches the provider-agnostic design already sketched in
-- notification_service.dart (NotificationChannel enum: sms/whatsapp/email/push).
-- Today that service only calls debugPrint() — this schema is what an Edge
-- Function-based dispatcher (P7) will read from and log to.

create type notification_channel as enum ('sms', 'whatsapp', 'email', 'push');

create table notification_templates (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique, -- e.g. 'order_received', 'payment_confirmed', 'dispatched'
  channel notification_channel not null,
  template_body text not null,
  is_active boolean not null default true
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders (id) on delete set null,
  recipient text not null, -- phone/email/device token
  channel notification_channel not null,
  event_key text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index idx_notifications_order on notifications (order_id);

-- Every notification attempt is logged, including failures (§37).
create table notification_logs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references notifications (id) on delete cascade,
  provider text,
  provider_reference text,
  status text not null default 'queued', -- queued | sent | delivered | failed
  failure_reason text,
  sent_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_notification_logs_notification on notification_logs (notification_id);
