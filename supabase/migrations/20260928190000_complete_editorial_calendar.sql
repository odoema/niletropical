-- Complete editorial calendar planning model.
create table if not exists public.editorial_calendar_dates (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  name text not null,
  category text not null check (category in ('uganda_public','uganda_cultural','global_observance','campaign')),
  description text,
  recurring_rule text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(date,name)
);
create index if not exists editorial_calendar_dates_date_idx on public.editorial_calendar_dates(date);
create index if not exists editorial_calendar_dates_category_idx on public.editorial_calendar_dates(category);

create table if not exists public.editorial_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  theme text,
  description text,
  starts_on date not null,
  ends_on date not null,
  status text not null default 'planned' check (status in ('planned','active','completed','archived')),
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);
create index if not exists editorial_campaigns_dates_idx on public.editorial_campaigns(starts_on,ends_on);

create table if not exists public.editorial_campaign_items (
  campaign_id uuid not null references public.editorial_campaigns(id) on delete cascade,
  item_id uuid not null references public.publishing_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(campaign_id,item_id)
);

alter table public.editorial_calendar_dates enable row level security;
alter table public.editorial_campaigns enable row level security;
alter table public.editorial_campaign_items enable row level security;

drop policy if exists "calendar_dates_staff_read" on public.editorial_calendar_dates;
drop policy if exists "calendar_dates_manage" on public.editorial_calendar_dates;
drop policy if exists "campaigns_staff_read" on public.editorial_campaigns;
drop policy if exists "campaigns_manage" on public.editorial_campaigns;
drop policy if exists "campaign_items_staff_read" on public.editorial_campaign_items;
drop policy if exists "campaign_items_manage" on public.editorial_campaign_items;

create policy "calendar_dates_staff_read" on public.editorial_calendar_dates for select to authenticated using (public.is_staff());
create policy "calendar_dates_manage" on public.editorial_calendar_dates for all to authenticated using (public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role)) with check (public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role));
create policy "campaigns_staff_read" on public.editorial_campaigns for select to authenticated using (public.is_staff());
create policy "campaigns_manage" on public.editorial_campaigns for all to authenticated using (public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role)) with check (public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role));
create policy "campaign_items_staff_read" on public.editorial_campaign_items for select to authenticated using (public.is_staff());
create policy "campaign_items_manage" on public.editorial_campaign_items for all to authenticated using (public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role)) with check (public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role));

grant select,insert,update,delete on public.editorial_calendar_dates to authenticated;
grant select,insert,update,delete on public.editorial_campaigns to authenticated;
grant select,insert,update,delete on public.editorial_campaign_items to authenticated;

create or replace function public.reschedule_publishing_item(p_item_id uuid,p_scheduled_at timestamptz,p_note text default null)
returns public.publishing_items
language plpgsql security invoker
set search_path = pg_catalog, public
as $$
declare v_old timestamptz; v_row public.publishing_items;
begin
 if not (public.has_role('manager'::public.app_role) or public.has_role('super_admin'::public.app_role)) then
   raise exception 'Only managers and super admins can reschedule publications';
 end if;
 select scheduled_at into v_old from public.publishing_items where id=p_item_id for update;
 if not found then raise exception 'Publishing item not found'; end if;
 update public.publishing_items set scheduled_at=p_scheduled_at,updated_by=auth.uid(),updated_at=now()
 where id=p_item_id returning * into v_row;
 insert into public.publishing_item_events(item_id,actor_id,event_type,from_status,to_status,note)
 values(p_item_id,auth.uid(),'scheduled',v_row.status,v_row.status,
 coalesce(p_note,'Calendar reschedule from '||coalesce(v_old::text,'unscheduled')||' to '||p_scheduled_at::text));
 return v_row;
end $$;

revoke all on function public.reschedule_publishing_item(uuid,timestamptz,text) from public;
grant execute on function public.reschedule_publishing_item(uuid,timestamptz,text) to authenticated;