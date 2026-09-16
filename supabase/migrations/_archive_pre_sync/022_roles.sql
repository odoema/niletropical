-- 022_roles.sql
--
-- FIX (2026-09-11): the prior version updated `profiles.role` — but the
-- profiles table (002_profiles_roles.sql) has no `role` column. Roles live
-- in the separate `user_roles` table (many-to-many, so one staff member can
-- hold e.g. manager + finance), keyed by the `app_role` enum:
--
--     super_admin, manager, sales, inventory, finance, content, courier
--
-- The `has_role()` and `is_staff()` helpers in 002 read that table, and
-- every RLS policy in 014_rls.sql goes through them. That is the role
-- model — nothing on profiles to update.
--
-- The master contract (§32) lists a different set — customer,
-- inventory_officer, manager, admin, super_admin, courier — but adopting
-- that would require coordinated changes to the enum (002), every policy
-- in 014, and the client-side role checks that will land in P10. It is
-- deliberately deferred rather than done half-way here.
--
-- This migration is a no-op so filename ordering is preserved and
-- `supabase db push` runs cleanly.

DO $$
BEGIN
  RAISE NOTICE
    '022_roles: no-op. Role model is app_role enum + user_roles table + '
    'has_role() helper from 002_profiles_roles.sql, enforced by RLS in '
    '014_rls.sql. See AUDIT.md for the full explanation.';
END $$;
