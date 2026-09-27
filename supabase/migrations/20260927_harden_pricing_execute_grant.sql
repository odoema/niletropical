-- Reconciliation-only hardening.
-- The function body already requires manager/finance/super_admin.
-- Remove the unnecessary anonymous EXECUTE surface while retaining
-- authenticated/service_role callers used by the application/admin paths.

revoke execute on function public.apply_pricing_recommendation(uuid) from anon;
grant execute on function public.apply_pricing_recommendation(uuid) to authenticated;
grant execute on function public.apply_pricing_recommendation(uuid) to service_role;
