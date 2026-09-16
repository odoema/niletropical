-- Nile Tropical Uganda — 002_profiles_roles.sql
-- Staff/admin identity and role-based access control.
-- Customer identity is handled separately in 005_customers.sql (guest checkout
-- is a first-class flow — customers are not required to have a Supabase Auth
-- account).

create type app_role as enum (
  'super_admin',
  'manager',
  'sales',
  'inventory',
  'finance',
  'content',
  'courier'
);

-- One row per Supabase Auth user who is staff. Customers who never log in
-- as staff will not have a row here.
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  phone text,
  email citext,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A user can hold more than one role (e.g. manager who also does finance).
create table user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  role app_role not null,
  created_at timestamptz not null default now(),
  unique (user_id, role)
);

create index idx_user_roles_user_id on user_roles (user_id);

-- Helper used throughout RLS policies (014_rls.sql) and by the app to check
-- "does the current authenticated user hold role X".
create or replace function has_role(_role app_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from user_roles ur
    join profiles p on p.id = ur.user_id
    where ur.user_id = auth.uid()
      and ur.role = _role
      and p.is_active
  );
$$;

-- Helper: is the current user any kind of active staff member at all.
create or replace function is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles p
    where p.id = auth.uid() and p.is_active
  );
$$;

create trigger set_updated_at_profiles
  before update on profiles
  for each row execute function trigger_set_updated_at();
