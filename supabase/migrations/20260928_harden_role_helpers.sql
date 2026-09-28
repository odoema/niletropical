-- Harden role helper RPCs: these are used by authenticated RLS/admin flows,
-- but should not be callable directly by anonymous clients.
revoke execute on function public.has_role(public.app_role) from anon;
revoke execute on function public.is_staff() from anon;
