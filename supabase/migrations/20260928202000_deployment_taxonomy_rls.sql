-- Deployment taxonomy is application metadata; staff may read it, but it is not writable through the public API.
alter table public.deployment_root_cause_taxonomy enable row level security;

drop policy if exists deployment_root_cause_taxonomy_staff_read on public.deployment_root_cause_taxonomy;
create policy deployment_root_cause_taxonomy_staff_read
on public.deployment_root_cause_taxonomy
for select
to authenticated
using ((select public.is_staff()));
