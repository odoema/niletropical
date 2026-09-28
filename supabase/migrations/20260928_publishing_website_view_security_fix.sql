-- Public article view must obey the querying role's RLS.
drop view if exists public.published_articles;
create view public.published_articles
with (security_invoker = true)
as
select
  pi.id, pi.title, pi.content_type, pi.slug, pi.body, pi.caption,
  pi.byline, pi.source_note, pi.cover_media_path, pi.tags,
  pi.published_at, pi.created_at
from public.publishing_items pi
where pi.status = 'published'
  and (pi.embargo_until is null or pi.embargo_until <= now());

grant select on public.published_articles to anon, authenticated;