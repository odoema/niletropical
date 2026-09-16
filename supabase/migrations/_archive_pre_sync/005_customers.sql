-- Nile Tropical Uganda — 005_customers.sql
-- Guest checkout is required (§44 — "Do not force registration"), so a
-- customer row can exist with no linked auth.users account. If a customer
-- later creates an account, auth_user_id is backfilled.

create table customers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users (id) on delete set null,
  full_name text not null,
  phone text not null,
  email citext,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (phone)
);

create index idx_customers_auth_user on customers (auth_user_id);

create type address_label as enum ('home', 'office', 'shop', 'other');

create table customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers (id) on delete cascade,
  label address_label not null default 'home',
  district text,
  city_town text,
  area text,
  address_line text,
  landmark text,
  delivery_instructions text,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_customer_addresses_customer on customer_addresses (customer_id);

create trigger set_updated_at_customers
  before update on customers for each row execute function trigger_set_updated_at();
