-- 20260924_fix_generate_order_number.sql
-- Production repair: create_order expects a zero-argument order number
-- generator, but the production database does not currently contain one.
-- Keep the generator independent of sequences so it is safe to install on
-- an existing production database.

CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN 'NT-' ||
         to_char(clock_timestamp(), 'YYYYMMDD-HH24MISSMS') ||
         '-' ||
         upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_order_number()
  TO anon, authenticated;
