-- 20260928_publishing_studio.sql
-- Editorial/newsroom publishing workspace.
alter type public.app_role add value if not exists 'journalist';

create table if not exists public.publishing_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content_type text not null default 'social_post' check (content_type in ('social_post','news_story','press_release','announcement','photo_story','video_story')),
  slug text,
  body text,
  caption text,
  byline text,
  source_note text,
  cover_media_path text,
  tags text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft','in_review','approved','scheduled','published','archived')),
  scheduled_at timestamptz,
  embargo_until timestamptz,
  published_at timestamptz,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.publishing_targets (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.publishing_items(id) on delete cascade,
  channel text not null check (channel in ('website','facebook','instagram','linkedin','x','youtube','whatsapp','newsletter','press')),
  headline text,
  copy text,
  media_paths text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft','ready','scheduled','published','failed')),
  scheduled_at timestamptz,
  published_at timestamptz,
  external_url text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(item_id, channel)
);

create index if not exists publishing_items_status_idx on public.publishing_items(status);
create index if not exists publishing_items_schedule_idx on public.publishing_items(scheduled_at);
create index if not exists publishing_targets_item_idx on public.publishing_targets(item_id);
create index if not exists publishing_targets_channel_status_idx on public.publishing_targets(channel,status);

alter table public.publishing_items enable row level security;
alter table public.publishing_targets enable row level security;

create policy "publishing_items_staff_read" on public.publishing_items
for select to authenticated using (public.is_staff());

create policy "publishing_items_content_write" on public.publishing_items
for all to authenticated
using (public.has_role('journalist'::public.app_role) or public.has_role('content_manager'::public.app_role) or public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role))
with check (public.has_role('journalist'::public.app_role) or public.has_role('content_manager'::public.app_role) or public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role));

create policy "publishing_targets_staff_read" on public.publishing_targets
for select to authenticated using (public.is_staff());

create policy "publishing_targets_content_write" on public.publishing_targets
for all to authenticated
using (public.has_role('journalist'::public.app_role) or public.has_role('content_manager'::public.app_role) or public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role))
with check (public.has_role('journalist'::public.app_role) or public.has_role('content_manager'::public.app_role) or public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role));

grant select, insert, update, delete on public.publishing_items to authenticated;
grant select, insert, update, delete on public.publishing_targets to authenticated;