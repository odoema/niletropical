-- 024_cleanup_create_order_overloads.sql
-- Remove legacy create_order overloads that cause PostgREST PGRST203
-- ambiguous-function errors in production.
--
-- Supported production signature:
-- create_order(text, text, text, text, text, uuid, text, jsonb, text)

DROP FUNCTION IF EXISTS public.create_order(
  text,
  text,
  text,
  text,
  jsonb,
  uuid,
  text,
  jsonb,
  text,
  text
);

-- Defensive cleanup for an older JSONB-address, no-coupon variant.
-- The supported text-address signature is not affected.
DROP FUNCTION IF EXISTS public.create_order(
  text,
  text,
  text,
  text,
  jsonb,
  uuid,
  text,
  jsonb,
  text
);
