-- Reconciliation-only execution-surface hardening.
-- DO NOT deploy until caller-path regression tests pass.
--
-- courier_login_status accepts an arbitrary user UUID and is intended for
-- courier authentication. The current public execution surface exposes
-- profile/role/courier state for any supplied UUID, so it should not remain
-- anonymously callable.
--
-- link_current_user_customer derives identity only from auth.uid(); retain
-- authenticated execution and remove anonymous execution.

revoke execute on function public.courier_login_status(uuid) from anon;
grant execute on function public.courier_login_status(uuid) to authenticated;
grant execute on function public.courier_login_status(uuid) to service_role;

revoke execute on function public.link_current_user_customer() from anon;
grant execute on function public.link_current_user_customer() to authenticated;
grant execute on function public.link_current_user_customer() to service_role;
