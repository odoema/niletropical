-- Nile Tropical Uganda — 003_catalog.sql
-- Field names match lib/shared/models/product.dart's fromJson() keys exactly
-- so the existing Flutter query/parsing code (supabase_service.dart,
-- product.dart) works unmodified once this schema exists.

create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  parent_id uuid references categories (id) on delete set null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  short_description text,
  full_description text,
  benefits text,
  how_to_use text,
  ingredients text,
  warnings text,
  brand text not null default 'Nile Tropical',
  category_id uuid references categories (id) on delete set null,
  is_featured boolean not null default false,
  is_bestseller boolean not null default false,
  is_new boolean not null default false,
  is_promotional boolean not null default false,
  is_active boolean not null default true,
  -- SEO (§61)
  seo_title text,
  seo_description text,
  -- soft delete so historical order snapshots never dangle (§55)
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_products_active on products (is_active) where deleted_at is null;
create index idx_products_featured on products (is_featured) where is_active and deleted_at is null;
create index idx_products_category on products (category_id);
create index idx_products_search on products using gin (
  (coalesce(name, '') || ' ' || coalesce(short_description, '')) gin_trgm_ops
);

create table product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  sku text not null unique,
  name text not null,
  price numeric(12, 2) not null check (price >= 0),
  cost_price numeric(12, 2) check (cost_price is null or cost_price >= 0),
  compare_at_price numeric(12, 2) check (compare_at_price is null or compare_at_price >= 0),
  stock_quantity int not null default 0 check (stock_quantity >= 0),
  reorder_level int not null default 5 check (reorder_level >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_variants_product on product_variants (product_id);
create index idx_variants_sku on product_variants (sku);

create table product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  variant_id uuid references product_variants (id) on delete cascade,
  storage_path text not null,
  alt_text text,
  sort_order int not null default 0,
  is_main boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_product_images_product on product_images (product_id);

create table product_videos (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  storage_path text not null,
  thumbnail_path text,
  title text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index idx_product_videos_product on product_videos (product_id);

create trigger set_updated_at_categories
  before update on categories for each row execute function trigger_set_updated_at();
create trigger set_updated_at_products
  before update on products for each row execute function trigger_set_updated_at();
create trigger set_updated_at_product_variants
  before update on product_variants for each row execute function trigger_set_updated_at();
