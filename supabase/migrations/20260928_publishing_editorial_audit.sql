-- Editorial accountability and review history.
create table if not exists public.publishing_item_events (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.publishing_items(id) on delete cascade,
  actor_id uuid references auth.users(id),
  event_type text not null check (event_type in ('created','updated','submitted','approved','rejected','scheduled','published','archived','channel_updated')),
  from_status text,
  to_status text,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists publishing_item_events_item_idx on public.publishing_item_events(item_id, created_at desc);
create index if not exists publishing_item_events_actor_idx on public.publishing_item_events(actor_id, created_at desc);
alter table public.publishing_item_events enable row level security;
create policy "publishing_item_events_staff_read" on public.publishing_item_events
for select to authenticated using (public.is_staff());
create policy "publishing_item_events_content_write" on public.publishing_item_events
for insert to authenticated
with check (public.has_role('journalist'::public.app_role) or public.has_role('content_manager'::public.app_role) or public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role));
grant select, insert on public.publishing_item_events to authenticated;
