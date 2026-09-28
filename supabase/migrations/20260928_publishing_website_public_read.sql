-- Public website publishing bridge for editorial content.
-- Published, non-embargoed stories are readable anonymously; editorial writes remain staff-only.

grant select on public.publishing_items to anon, authenticated;

drop policy if exists "publishing_items_public_published_read" on public.publishing_items;
create policy "publishing_items_public_published_read"
on public.publishing_items
for select to anon, authenticated
using (
  status = 'published'
  and (embargo_until is null or embargo_until <= now())
);

create or replace function private.ensure_publishing_slug()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_slug text;
  candidate text;
  suffix text;
begin
  if new.slug is not null and btrim(new.slug) <> '' then
    new.slug := lower(regexp_replace(btrim(new.slug), '[^a-zA-Z0-9]+', '-', 'g'));
    new.slug := regexp_replace(new.slug, '(^-+|-+$)', '', 'g');
    return new;
  end if;

  base_slug := lower(regexp_replace(coalesce(new.title, 'story'), '[^a-zA-Z0-9]+', '-', 'g'));
  base_slug := regexp_replace(base_slug, '(^-+|-+$)', '', 'g');
  if base_slug = '' then base_slug := 'story'; end if;

  candidate := base_slug;
  if exists (select 1 from public.publishing_items where lower(slug) = lower(candidate) and id <> new.id) then
    suffix := substr(replace(new.id::text, '-', ''), 1, 8);
    candidate := base_slug || '-' || suffix;
  end if;
  new.slug := candidate;
  return new;
end;
$$;

revoke all on function private.ensure_publishing_slug() from public, anon, authenticated;

drop trigger if exists publishing_items_ensure_slug on public.publishing_items;
create trigger publishing_items_ensure_slug
before insert or update of title, slug on public.publishing_items
for each row execute function private.ensure_publishing_slug();
