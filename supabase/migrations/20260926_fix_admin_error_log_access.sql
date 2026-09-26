-- Nile Tropical — allow administrators to use the Error Logs console.
-- The application router already restricts /admin to staff roles; this policy
-- keeps database access limited to operational staff rather than all users.

drop policy if exists app_error_logs_staff_read on public.app_error_logs;
create policy app_error_logs_staff_read
  on public.app_error_logs
  for select
  to authenticated
  using (
    (select has_role('admin'))
    or (select has_role('manager'))
    or (select has_role('finance'))
    or (select has_role('super_admin'))
  );

drop policy if exists app_error_logs_staff_update on public.app_error_logs;
create policy app_error_logs_staff_update
  on public.app_error_logs
  for update
  to authenticated
  using (
    (select has_role('admin'))
    or (select has_role('manager'))
    or (select has_role('finance'))
    or (select has_role('super_admin'))
  )
  with check (
    (select has_role('admin'))
    or (select has_role('manager'))
    or (select has_role('finance'))
    or (select has_role('super_admin'))
  );
