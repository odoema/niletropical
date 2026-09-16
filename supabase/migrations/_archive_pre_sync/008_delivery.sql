-- Nile Tropical Uganda — 008_delivery.sql
-- Matches lib/shared/models/delivery.dart. Today delivery_service.dart has
-- zero Supabase calls (100% mock) — this schema is what P6 wires it to.

create type delivery_partner_type as enum (
  'bus', 'taxi', 'courier_company', 'boda', 'other'
);

-- Delivery fees must be admin/config driven, never hard-coded in Flutter
-- (§23). This replaces delivery_service.dart's _mockZones list.
create table delivery_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  delivery_fee numeric(12, 2) not null check (delivery_fee >= 0),
  estimated_days int,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table orders
  add constraint fk_orders_delivery_zone
  foreign key (delivery_zone_id) references delivery_zones (id) on delete set null;

create table delivery_partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type delivery_partner_type not null default 'other',
  contact_person text,
  phone text,
  email citext,
  terminal text,
  routes text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table couriers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users (id) on delete set null,
  full_name text not null,
  phone text not null,
  id_number text,
  vehicle_type text,
  registration_number text,
  operating_area text,
  commission_rate numeric(5, 2),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_couriers_auth_user on couriers (auth_user_id);

-- Order and shipment are deliberately separate objects (§30) so split
-- shipments are possible later without a redesign.
create table shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
  delivery_partner_id uuid references delivery_partners (id) on delete set null,
  courier_id uuid references couriers (id) on delete set null,
  tracking_reference text,
  status text not null default 'pending',
  dispatched_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_shipments_order on shipments (order_id);
create index idx_shipments_courier on shipments (courier_id);

create table delivery_events (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references shipments (id) on delete cascade,
  event_type text not null, -- DISPATCHED_TO_TRANSPORT | ARRIVED_AT_TERMINAL | CUSTOMER_NOTIFIED | COURIER_ASSIGNED | COURIER_PICKED_UP | OUT_FOR_DELIVERY | DELIVERED
  actor uuid references profiles (id) on delete set null,
  location text,
  notes text,
  reference text,
  created_at timestamptz not null default now()
);

create index idx_delivery_events_shipment on delivery_events (shipment_id);

create table proof_of_delivery (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references shipments (id) on delete cascade,
  courier_id uuid references couriers (id) on delete set null,
  delivered_at timestamptz not null default now(),
  recipient_name text,
  otp_or_signature text,
  photo_storage_path text,
  location text,
  cod_amount_collected numeric(12, 2),
  created_at timestamptz not null default now()
);

create index idx_pod_shipment on proof_of_delivery (shipment_id);

create trigger set_updated_at_delivery_zones
  before update on delivery_zones for each row execute function trigger_set_updated_at();
create trigger set_updated_at_delivery_partners
  before update on delivery_partners for each row execute function trigger_set_updated_at();
create trigger set_updated_at_couriers
  before update on couriers for each row execute function trigger_set_updated_at();
create trigger set_updated_at_shipments
  before update on shipments for each row execute function trigger_set_updated_at();
