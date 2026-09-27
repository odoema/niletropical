-- Reconciliation-only function hardening.
-- Live signature and mutable search_path were verified on production.
-- DO NOT deploy until migration review and regression tests pass.

alter function public.trigger_set_updated_at()
  set search_path = public;

-- Trigger-only function; it is not an RPC surface.
revoke execute on function public.trigger_set_updated_at() from anon, authenticated;
