-- Nile Tropical Uganda — 001_extensions.sql
-- Enable required Postgres extensions.

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- trigram search (product name/description)
create extension if not exists "citext";     -- case-insensitive email storage

-- Shared trigger function used by every table below that has an
-- `updated_at` column, so it doesn't need to be redefined per-table.
create or replace function trigger_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
