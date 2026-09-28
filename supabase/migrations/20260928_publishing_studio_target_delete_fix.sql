-- Allow journalists/content managers to replace channel plans while an item is editable.
drop policy if exists "publishing_targets_editor_delete" on public.publishing_targets;
create policy "publishing_targets_editor_delete"
on public.publishing_targets
for delete to authenticated
using (
  (
    (
      (select public.has_role('journalist'::public.app_role))
      or (select public.has_role('content_manager'::public.app_role))
    )
    and exists (
      select 1 from public.publishing_items i
      where i.id = item_id and i.status in ('draft','in_review')
    )
  )
  or (select public.has_role('manager'::public.app_role))
  or (select public.has_role('super_admin'::public.app_role))
);