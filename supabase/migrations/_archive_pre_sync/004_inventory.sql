-- Nile Tropical Uganda — 004_inventory.sql
-- Matches lib/shared/models/inventory.dart's StockMovementType, Batch and
-- StockMovement classes. The actual atomic stock mutation function
-- (replacing inventory_service.dart's unsafe read-calculate-write) lives in
-- 013_functions.sql, once orders/order_items exist for it to reference.

create type stock_movement_type as enum (
  'purchase',
  'sale',
  'return',
  'damage',
  'expiry',
  'adjustment',
  'transfer',
  'opening'
);

create table batches (
  id uuid primary key default gen_random_uuid(),
  product_variant_id uuid not null references product_variants (id) on delete cascade,
  batch_number text not null,
  manufacturing_date date,
  expiry_date date,
  quantity int not null check (quantity >= 0),
  notes text,
  created_at timestamptz not null default now(),
  unique (product_variant_id, batch_number)
);

create index idx_batches_variant on batches (product_variant_id);
create index idx_batches_expiry on batches (expiry_date) where expiry_date is not null;

create table stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_variant_id uuid not null references product_variants (id) on delete restrict,
  batch_id uuid references batches (id) on delete set null,
  movement_type stock_movement_type not null,
  quantity int not null check (quantity <> 0), -- negative = decrease, positive = increase
  reference text,     -- e.g. order_number or purchase-order number
  notes text,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index idx_stock_movements_variant on stock_movements (product_variant_id);
create index idx_stock_movements_created_at on stock_movements (created_at desc);
create index idx_stock_movements_reference on stock_movements (reference);
