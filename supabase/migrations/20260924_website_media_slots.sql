-- Website CMS media slots
create table if not exists public.website_media_slots (
  slot_key text primary key,
  label text not null,
  storage_path text,
  alt_text text,
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

insert into public.website_media_slots (slot_key, label, storage_path, alt_text)
values
  ('logo','Website logo','website/niletropical-logo.jpg','Nile Tropical Industries Ltd logo'),
  ('hero','Homepage hero',null,'Nile Tropical Industries homepage'),
  ('mozzie','Mozzie product image','website/mozzie.jpg','Mozzie-Guard Jelly'),
  ('founder','Founder image','website/founder.jpg','Nile Tropical Industries founder'),
  ('story','Our story image',null,'Nile Tropical Industries story'),
  ('market','Market image',null,'West Nile market')
on conflict (slot_key) do nothing;

alter table public.website_media_slots enable row level security;

drop policy if exists website_media_slots_public_read on public.website_media_slots;
create policy website_media_slots_public_read on public.website_media_slots for select using (is_active = true);

drop policy if exists website_media_slots_staff_read on public.website_media_slots;
create policy website_media_slots_staff_read on public.website_media_slots for select to authenticated using (public.is_staff());

drop policy if exists website_media_slots_content_write on public.website_media_slots;
create policy website_media_slots_content_write on public.website_media_slots
for all to authenticated
using (public.has_role('content'::app_role) or public.has_role('manager'::app_role) or public.has_role('super_admin'::app_role))
with check (public.has_role('content'::app_role) or public.has_role('manager'::app_role) or public.has_role('super_admin'::app_role));

drop trigger if exists set_updated_at_website_media_slots on public.website_media_slots;
create trigger set_updated_at_website_media_slots
before update on public.website_media_slots
for each row execute function public.trigger_set_updated_at();

create index if not exists idx_website_media_slots_active on public.website_media_slots(is_active);

insert into storage.buckets (id, name, public)
values ('cms','cms',true)
on conflict (id) do update set public = true;

drop policy if exists cms_public_read on storage.objects;
create policy cms_public_read on storage.objects
for select using (bucket_id = 'cms');

drop policy if exists cms_staff_insert on storage.objects;
create policy cms_staff_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'cms' and public.is_staff());

drop policy if exists cms_staff_update on storage.objects;
create policy cms_staff_update on storage.objects
for update to authenticated
using (bucket_id = 'cms' and public.is_staff())
with check (bucket_id = 'cms' and public.is_staff());

drop policy if exists cms_staff_delete on storage.objects;
create policy cms_staff_delete on storage.objects
for delete to authenticated
using (bucket_id = 'cms' and public.is_staff());
