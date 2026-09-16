-- Nile Tropical Uganda — 010_promotions.sql

create table promotions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create type discount_type as enum ('percentage', 'fixed_amount');

create table discounts (
  id uuid primary key default gen_random_uuid(),
  promotion_id uuid references promotions (id) on delete cascade,
  product_id uuid references products (id) on delete cascade,
  variant_id uuid references product_variants (id) on delete cascade,
  discount_type discount_type not null,
  value numeric(12, 2) not null check (value >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_type discount_type not null,
  value numeric(12, 2) not null check (value >= 0),
  max_uses int,
  used_count int not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Admin-controlled flagship-product popup (§43).
create table promotional_popups (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text,
  image_storage_path text,
  product_id uuid references products (id) on delete set null,
  cta_label text,
  cta_url text,
  is_active boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  display_frequency text not null default 'once_per_session', -- once_per_session | once_per_day | always
  mobile_enabled boolean not null default true,
  desktop_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_updated_at_promotional_popups
  before update on promotional_popups for each row execute function trigger_set_updated_at();
