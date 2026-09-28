revoke select on table public.publishing_items from anon;

create or replace view public.published_articles
with (security_barrier = true)
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
);

grant select on public.published_articles to anon, authenticated;