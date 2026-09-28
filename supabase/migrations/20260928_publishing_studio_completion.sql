-- 20260928_publishing_studio_completion.sql
-- Complete newsroom workflow: role-gated editorial transitions, review metadata,
-- append-only audit logging, and target/media integrity.

alter table public.publishing_items
  add column if not exists reviewed_by uuid references auth.users(id),
  add column if not exists reviewed_at timestamptz,
  add column if not exists review_note text;

create index if not exists publishing_items_reviewed_by_idx
  on public.publishing_items(reviewed_by);

-- Replace the original broad ALL policies with operation-specific policies.
drop policy if exists "publishing_items_content_write" on public.publishing_items;
drop policy if exists "publishing_targets_content_write" on public.publishing_targets;
drop policy if exists "publishing_item_events_content_write" on public.publishing_item_events;

create policy "publishing_items_editor_insert"
on public.publishing_items
for insert to authenticated
with check (
  (select public.has_role('journalist'::public.app_role))
  or (select public.has_role('content_manager'::public.app_role))
  or (select public.has_role('manager'::public.app_role))
  or (select public.has_role('super_admin'::public.app_role))
);

create policy "publishing_items_editor_update"
on public.publishing_items
for update to authenticated
using (
  (
    (
      (select public.has_role('journalist'::public.app_role))
      or (select public.has_role('content_manager'::public.app_role))
    )
    and status in ('draft','in_review')
  )
  or (select public.has_role('manager'::public.app_role))
  or (select public.has_role('super_admin'::public.app_role))
)
with check (
  (
    (
      (select public.has_role('journalist'::public.app_role))
      or (select public.has_role('content_manager'::public.app_role))
    )
    and status in ('draft','in_review')
  )
  or (select public.has_role('manager'::public.app_role))
  or (select public.has_role('super_admin'::public.app_role))
);

create policy "publishing_items_manager_delete"
on public.publishing_items
for delete to authenticated
using (
  (select public.has_role('manager'::public.app_role))
  or (select public.has_role('super_admin'::public.app_role))
);

create policy "publishing_targets_editor_insert"
on public.publishing_targets
for insert to authenticated
with check (
  (
    (select public.has_role('journalist'::public.app_role))
    or (select public.has_role('content_manager'::public.app_role))
  )
  and exists (
    select 1 from public.publishing_items i
    where i.id = item_id and i.status in ('draft','in_review')
  )
);

create policy "publishing_targets_editor_update"
on public.publishing_targets
for update to authenticated
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
)
with check (
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

create policy "publishing_targets_manager_delete"
on public.publishing_targets
for delete to authenticated
using (
  (select public.has_role('manager'::public.app_role))
  or (select public.has_role('super_admin'::public.app_role))
);

-- Audit history is read-only through the client. Database triggers own the writes.
revoke insert on public.publishing_item_events from authenticated;
revoke update, delete on public.publishing_item_events from authenticated;
grant select on public.publishing_item_events to authenticated;

create schema if not exists private;

create or replace function private.enforce_publishing_workflow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(new.updated_by, new.created_by, auth.uid());
  privileged boolean := exists (
    select 1
    from public.user_roles
    where user_id = actor
      and role in ('manager'::public.app_role, 'super_admin'::public.app_role)
  );
begin
  if tg_op = 'INSERT' then
    if new.status not in ('draft','in_review') and not privileged then
      raise exception 'Editorial item must enter review before approval or publication';
    end if;
    if new.status = 'in_review' and not (
      exists (
        select 1 from public.user_roles
        where user_id = actor
          and role in (
            'journalist'::public.app_role,
            'content_manager'::public.app_role,
            'manager'::public.app_role,
            'super_admin'::public.app_role
          )
      )
    ) then
      raise exception 'User is not authorized for editorial workflow';
    end if;
    return new;
  end if;

  if new.status = 'approved' then
    if old.status <> 'in_review' then
      raise exception 'Only items in review can be approved';
    end if;
    if not privileged then
      raise exception 'Only a manager or super admin can approve content';
    end if;
    new.reviewed_by := actor;
    new.reviewed_at := now();
  elsif new.status = 'scheduled' then
    if old.status <> 'approved' then
      raise exception 'Only approved content can be scheduled';
    end if;
    if new.scheduled_at is null then
      raise exception 'Scheduled content requires scheduled_at';
    end if;
    if not privileged then
      raise exception 'Only a manager or super admin can schedule content';
    end if;
  elsif new.status = 'published' then
    if old.status not in ('approved','scheduled') then
      raise exception 'Only approved or scheduled content can be published';
    end if;
    if not privileged then
      raise exception 'Only a manager or super admin can publish content';
    end if;
    if new.embargo_until is not null and new.embargo_until > now() then
      raise exception 'Embargo is still active';
    end if;
    new.published_at := coalesce(new.published_at, now());
  elsif new.status = 'archived' then
    if not privileged then
      raise exception 'Only a manager or super admin can archive content';
    end if;
  elsif new.status = 'in_review' then
    if old.status not in ('draft','in_review') then
      raise exception 'Only draft content can be submitted for review';
    end if;
  elsif new.status = 'draft' then
    if old.status in ('approved','scheduled','published','archived') and not privileged then
      raise exception 'Only a manager or super admin can return published workflow to draft';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_publishing_workflow() from public, anon, authenticated;

drop trigger if exists publishing_workflow_guard on public.publishing_items;
create trigger publishing_workflow_guard
before insert or update of status, scheduled_at, embargo_until, published_at
on public.publishing_items
for each row execute function private.enforce_publishing_workflow();

create or replace function private.log_publishing_item_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(new.updated_by, new.created_by, old.updated_by, old.created_by, auth.uid());
  event_name text;
begin
  if tg_op = 'INSERT' then
    event_name := case when new.status = 'in_review' then 'submitted' else 'created' end;
    insert into public.publishing_item_events(item_id,actor_id,event_type,from_status,to_status,note)
    values (new.id, actor, event_name, null, new.status, new.review_note);
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    event_name := case
      when new.status = 'in_review' then 'submitted'
      when new.status = 'approved' then 'approved'
      when new.status = 'scheduled' then 'scheduled'
      when new.status = 'published' then 'published'
      when new.status = 'archived' then 'archived'
      when new.status = 'draft' and old.status = 'in_review' then 'rejected'
      else 'updated'
    end;
    insert into public.publishing_item_events(item_id,actor_id,event_type,from_status,to_status,note)
    values (new.id, actor, event_name, old.status, new.status, new.review_note);
  end if;

  return new;
end;
$$;

revoke all on function private.log_publishing_item_event() from public, anon, authenticated;

drop trigger if exists publishing_item_audit on public.publishing_items;
create trigger publishing_item_audit
after insert or update of status,review_note,reviewed_by,reviewed_at
on public.publishing_items
for each row execute function private.log_publishing_item_event();

create or replace function private.log_publishing_target_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(
    (select updated_by from public.publishing_items where id = coalesce(new.item_id, old.item_id)),
    auth.uid()
  );
begin
  insert into public.publishing_item_events(item_id,actor_id,event_type,note)
  values (
    coalesce(new.item_id, old.item_id),
    actor,
    'channel_updated',
    case
      when tg_op = 'DELETE' then 'Removed channel ' || old.channel
      when tg_op = 'INSERT' then 'Added channel ' || new.channel
      else 'Updated channel ' || new.channel
    end
  );
  return coalesce(new, old);
end;
$$;

revoke all on function private.log_publishing_target_event() from public, anon, authenticated;

drop trigger if exists publishing_target_audit on public.publishing_targets;
create trigger publishing_target_audit
after insert or update or delete on public.publishing_targets
for each row execute function private.log_publishing_target_event();
