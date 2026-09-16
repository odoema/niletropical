-- Nile Tropical Uganda — 012_audit.sql
-- Administrative actions that must be traceable (§48): price changes, stock
-- adjustments, cancellations, refunds, manual payment edits, courier
-- reassignment, role changes.

create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor uuid references profiles (id) on delete set null,
  action text not null,       -- e.g. 'product.price_changed', 'order.cancelled'
  entity_type text not null,  -- e.g. 'products', 'orders'
  entity_id uuid not null,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default now()
);

create index idx_audit_logs_entity on audit_logs (entity_type, entity_id);
create index idx_audit_logs_actor on audit_logs (actor);
create index idx_audit_logs_created_at on audit_logs (created_at desc);
