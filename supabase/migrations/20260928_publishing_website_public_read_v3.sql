-- Keep public article reads anonymous-only; staff access remains covered by the staff policy.
drop policy if exists "publishing_items_public_published_read" on public.publishing_items;
create policy "publishing_items_public_published_read"
on public.publishing_items
for select to anon
using (
  status = 'published'
  and (embargo_until is null or embargo_until <= now())
);