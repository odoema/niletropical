-- Nile Tropical Uganda — 006_orders.sql
-- Enum values and OrderItem snapshot fields are taken directly from the
-- existing lib/shared/models/order.dart, which the audit identified as
-- already well-designed and worth preserving rather than replacing.

create type order_status as enum (
  'new',
  'payment_pending',
  'payment_confirmed',
  'order_confirmed',
  'processing',
  'packed',
  'ready_for_dispatch',
  'dispatched',
  'in_transit',
  'arrived_at_destination',
  'out_for_delivery',
  'delivered',
  'cancelled',
  'refunded',
  'delivery_failed',
  'returned',
  'out_of_stock'
);

create type payment_status as enum (
  'unpaid', 'pending', 'paid', 'failed', 'refunded', 'partially_paid'
);

create type payment_method as enum (
  'mtn_momo', 'airtel_money', 'card', 'cash_on_delivery'
);

-- Server-side sequential, concurrency-safe order numbers (replaces the
-- client-side `DateTime.now().millisecondsSinceEpoch % 1000000` in
-- order_service.dart — see 013_functions.sql for generate_order_number()).
create sequence order_number_seq start 1;

create table orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_id uuid references customers (id) on delete set null,
  status order_status not null default 'new',
  payment_status payment_status not null default 'unpaid',
  payment_method payment_method,
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null default 0 check (delivery_fee >= 0),
  discount_total numeric(12, 2) not null default 0 check (discount_total >= 0),
  total numeric(12, 2) not null check (total >= 0),
  currency text not null default 'UGX',
  customer_name text not null,
  customer_phone text not null,
  delivery_zone_id uuid, -- fk added in 008_delivery.sql once delivery_zones exists
  delivery_address jsonb, -- {city, area, address, landmark, instructions}
  -- guest checkout access token so a customer without an account can view
  -- their own order via the public tracking screen (§35) without exposing
  -- every order to every visitor
  tracking_token uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_orders_customer on orders (customer_id);
create index idx_orders_status on orders (status);
create index idx_orders_payment_status on orders (payment_status);
create index idx_orders_created_at on orders (created_at desc);
create index idx_orders_tracking_token on orders (tracking_token);

-- Preserves productNameSnapshot / variantNameSnapshot / skuSnapshot exactly
-- as already modeled in order.dart's OrderItem, so historical orders never
-- change when the live catalogue changes (§55).
create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
  product_id uuid references products (id) on delete set null,
  variant_id uuid references product_variants (id) on delete set null,
  product_name_snapshot text not null,
  variant_name_snapshot text,
  sku_snapshot text,
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  discount numeric(12, 2) not null default 0 check (discount >= 0),
  quantity int not null check (quantity > 0),
  line_total numeric(12, 2) not null check (line_total >= 0)
);

create index idx_order_items_order on order_items (order_id);
create index idx_order_items_variant on order_items (variant_id);

-- Every status change must be logged (§27) and only valid transitions
-- allowed (§28) — transition validation lives in 013_functions.sql so it's
-- enforced no matter which client or admin action changes the status.
create table order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
  from_status order_status,
  to_status order_status not null,
  changed_by uuid references profiles (id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create index idx_order_status_history_order on order_status_history (order_id);

create trigger set_updated_at_orders
  before update on orders for each row execute function trigger_set_updated_at();
