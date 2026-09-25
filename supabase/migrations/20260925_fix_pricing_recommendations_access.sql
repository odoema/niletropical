-- 20260925_fix_pricing_recommendations_access.sql
-- Fix the admin Pricing screen: authenticated staff must be able to read
-- recommendations and update their workflow status.
--
-- The screen currently queries public.pricing_recommendations directly.
-- PostgreSQL therefore requires both table privileges and an RLS policy.

GRANT SELECT, UPDATE ON TABLE public.pricing_recommendations TO authenticated;

ALTER TABLE public.pricing_recommendations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pricing_recommendations_staff_read ON public.pricing_recommendations;
CREATE POLICY pricing_recommendations_staff_read
  ON public.pricing_recommendations
  FOR SELECT
  TO authenticated
  USING (
    has_role('manager')
    OR has_role('finance')
    OR has_role('super_admin')
  );

DROP POLICY IF EXISTS pricing_recommendations_staff_update ON public.pricing_recommendations;
CREATE POLICY pricing_recommendations_staff_update
  ON public.pricing_recommendations
  FOR UPDATE
  TO authenticated
  USING (
    has_role('manager')
    OR has_role('finance')
    OR has_role('super_admin')
  )
  WITH CHECK (
    has_role('manager')
    OR has_role('finance')
    OR has_role('super_admin')
  );
