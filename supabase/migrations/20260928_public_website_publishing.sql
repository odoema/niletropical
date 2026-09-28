-- Public website publishing surface for the Publishing Studio.
alter table public.publishing_items enable row level security;

drop policy if exists "publishing_items_public_website_read" on public.publishing_items;
create policy "publishing_items_public_website_read"
on public.publishing_items
for select
to anon
using (
  (
    (
      status = 'published'
      and (embargo_until is null or embargo_until <= now())
    )
    or
    (
      status = 'scheduled'
      and scheduled_at is not null
      and scheduled_at <= now()
      and (embargo_until is null or embargo_until <= now())
    )
  )
  and exists (
    select 1
    from public.publishing_targets pt
    where pt.item_id = publishing_items.id
      and pt.channel = 'website'
      and pt.status in ('published','scheduled')
  )
);

revoke select on table public.publishing_items from anon;
grant select (
  id,title,content_type,slug,body,caption,byline,cover_media_path,tags,
  scheduled_at,published_at,created_at
) on table public.publishing_items to anon;

create or replace view public.published_articles
with (security_invoker = true, security_barrier = true)
as
select
  pi.id,
  pi.title,
  pi.content_type,
  pi.slug,
  pi.body,
  pi.caption,
  pi.byline,
  pi.cover_media_path,
  pi.tags,
  pi.scheduled_at,
  pi.published_at,
  pi.created_at
from public.publishing_items pi
where (
  (
    (
      pi.status = 'published'
      and (pi.embargo_until is null or pi.embargo_until <= now())
    )
    or
    (
      pi.status = 'scheduled'
      and pi.scheduled_at is not null
      and pi.scheduled_at <= now()
      and (pi.embargo_until is null or pi.embargo_until <= now())
    )
  )
  and exists (
    select 1
    from public.publishing_targets pt
    where pt.item_id = pi.id
      and pt.channel = 'website'
      and pt.status in ('published','scheduled')
  )
);

grant select on public.published_articles to anon, authenticated;
