-- 024_cleanup_create_order_overloads.sql
-- Remove legacy create_order overloads that cause PostgREST PGRST203
-- ambiguous-function errors in production.
--
-- The supported production signature is:
-- (text, text, text, text, text, uuid, text, jsonb, text)

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

-- Re-assert the supported signature for clarity and future migrations.
-- 016_create_order_v2.sql owns the implementation and grant.
