-- Nile Tropical Uganda — 007_payments.sql
-- Payment status is derived server-side only, from verified provider
-- webhooks or manual COD collection confirmation (§24–§26) — the Flutter
-- client is never the authority on whether payment succeeded.

create table payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
  method payment_method not null,
  amount numeric(12, 2) not null check (amount >= 0),
  status payment_status not null default 'pending',
  -- COD-specific fields (§26)
  collected_by uuid references profiles (id) on delete set null,
  collected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_payments_order on payments (order_id);
create index idx_payments_status on payments (status);

-- One row per provider callback/webhook event. provider_reference has a
-- unique constraint so a duplicate webhook cannot create a second payment,
-- deduct stock again, or re-trigger notifications (§25 idempotency).
create table payment_transactions (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references payments (id) on delete cascade,
  provider text not null, -- 'mtn_momo' | 'airtel_money' | 'flutterwave' | 'pesapal' | ...
  provider_reference text not null,
  event_type text not null, -- e.g. 'charge.success', 'charge.failed'
  raw_payload jsonb not null,
  status payment_status not null,
  processed_at timestamptz not null default now(),
  unique (provider, provider_reference, event_type)
);

create index idx_payment_transactions_payment on payment_transactions (payment_id);

create trigger set_updated_at_payments
  before update on payments for each row execute function trigger_set_updated_at();
