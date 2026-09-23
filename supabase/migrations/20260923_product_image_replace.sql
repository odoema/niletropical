-- 2026-09-23 — production-safe product image replacement helper
-- Only replaces the main image reference for an existing product.
-- It does NOT alter product, variant, pricing, stock, or catalogue data.

CREATE OR REPLACE FUNCTION public.admin_replace_product_main_image(
  p_product_id uuid,
  p_storage_path text,
  p_alt_text text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_image_id uuid;
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff access required';
  END IF;

  IF p_product_id IS NULL OR NULLIF(trim(p_storage_path), '') IS NULL THEN
    RAISE EXCEPTION 'Product ID and storage path are required';
  END IF;

  UPDATE public.product_images
  SET
    storage_path = trim(p_storage_path),
    alt_text = COALESCE(NULLIF(trim(p_alt_text), ''), alt_text),
    is_main = true,
    sort_order = 0
  WHERE product_id = p_product_id
    AND is_main = true
  RETURNING id INTO v_image_id;

  IF v_image_id IS NULL THEN
    INSERT INTO public.product_images (
      product_id, storage_path, alt_text, sort_order, is_main
    )
    VALUES (
      p_product_id, trim(p_storage_path), NULLIF(trim(p_alt_text), ''), 0, true
    )
    RETURNING id INTO v_image_id;
  END IF;

  RETURN v_image_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_replace_product_main_image(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_replace_product_main_image(uuid, text, text) TO authenticated;
