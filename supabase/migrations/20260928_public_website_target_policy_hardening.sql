create or replace function private.publishing_website_target_ready(p_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.publishing_targets
    where item_id = p_item_id
      and channel = 'website'
      and status in ('published','scheduled')
  );
$$;

revoke execute on function private.publishing_website_target_ready(uuid) from public, authenticated;
grant execute on function private.publishing_website_target_ready(uuid) to anon;

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
  and (select private.publishing_website_target_ready(id))
);

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
);