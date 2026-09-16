-- Nile Tropical Uganda — 009_content.sql
-- CMS tables. Testimonials require explicit consent before publication —
-- especially for sensitive personal stories (§41) — enforced by
-- `requires_consent` + `consent_given` both needing to be true before
-- `published` can be set (checked in application logic / RLS, not just here).

create table testimonials (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  location text,
  photo_storage_path text,
  testimonial text not null,
  product_id uuid references products (id) on delete set null,
  video_storage_path text,
  consent_given boolean not null default false,
  is_published boolean not null default false,
  is_featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint testimonial_requires_consent_to_publish
    check (not is_published or consent_given)
);

create table customer_stories (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  cover_storage_path text,
  consent_given boolean not null default false,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint story_requires_consent_to_publish
    check (not is_published or consent_given)
);

create table videos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  storage_path text not null,
  thumbnail_path text,
  category text,
  is_published boolean not null default false,
  is_featured boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table banners (
  id uuid primary key default gen_random_uuid(),
  title text,
  image_storage_path text not null,
  link_url text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

create table pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  body text not null,
  is_published boolean not null default true,
  updated_at timestamptz not null default now()
);

create table faqs (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  answer text not null,
  sort_order int not null default 0,
  is_active boolean not null default true
);

create trigger set_updated_at_testimonials
  before update on testimonials for each row execute function trigger_set_updated_at();
create trigger set_updated_at_customer_stories
  before update on customer_stories for each row execute function trigger_set_updated_at();
create trigger set_updated_at_videos
  before update on videos for each row execute function trigger_set_updated_at();
create trigger set_updated_at_pages
  before update on pages for each row execute function trigger_set_updated_at();
