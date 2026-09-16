-- 019_admin_rpcs.sql — admin_upsert_product, zone & courier helpers (§25, §28)
--
-- FIX (2026-09-11): the prior version referenced columns that do not exist
-- (products.description, product_images.url/is_primary, delivery_zones.fee/
-- districts, couriers.delivery_partner_id). Rewritten against the actual
-- schema in 003_catalog.sql / 008_delivery.sql.

CREATE OR REPLACE FUNCTION admin_upsert_product(
  p_product jsonb,
  p_variants jsonb DEFAULT '[]'::jsonb,
  p_images jsonb DEFAULT '[]'::jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_var jsonb;
  v_img jsonb;
BEGIN
  IF p_product ? 'id' AND (p_product->>'id') IS NOT NULL THEN
    v_id := (p_product->>'id')::uuid;
    UPDATE products SET
      name              = coalesce(p_product->>'name', name),
      slug              = coalesce(p_product->>'slug', slug),
      short_description = coalesce(p_product->>'short_description', short_description),
      full_description  = coalesce(p_product->>'full_description', full_description),
      benefits          = coalesce(p_product->>'benefits', benefits),
      how_to_use        = coalesce(p_product->>'how_to_use', how_to_use),
      ingredients       = coalesce(p_product->>'ingredients', ingredients),
      warnings          = coalesce(p_product->>'warnings', warnings),
      is_active         = coalesce((p_product->>'is_active')::boolean, is_active),
      is_featured       = coalesce((p_product->>'is_featured')::boolean, is_featured),
      is_bestseller     = coalesce((p_product->>'is_bestseller')::boolean, is_bestseller),
      is_new            = coalesce((p_product->>'is_new')::boolean, is_new),
      is_promotional    = coalesce((p_product->>'is_promotional')::boolean, is_promotional),
      updated_at        = now()
    WHERE id = v_id;
  ELSE
    INSERT INTO products (
      name, slug, short_description, full_description, benefits, how_to_use,
      ingredients, warnings, is_active, is_featured, is_bestseller, is_new, is_promotional
    )
    VALUES (
      p_product->>'name',
      p_product->>'slug',
      p_product->>'short_description',
      p_product->>'full_description',
      p_product->>'benefits',
      p_product->>'how_to_use',
      p_product->>'ingredients',
      p_product->>'warnings',
      coalesce((p_product->>'is_active')::boolean,      true),
      coalesce((p_product->>'is_featured')::boolean,    false),
      coalesce((p_product->>'is_bestseller')::boolean,  false),
      coalesce((p_product->>'is_new')::boolean,         false),
      coalesce((p_product->>'is_promotional')::boolean, false)
    ) RETURNING id INTO v_id;
  END IF;

  FOR v_var IN SELECT * FROM jsonb_array_elements(p_variants)
  LOOP
    IF v_var ? 'id' AND (v_var->>'id') IS NOT NULL THEN
      UPDATE product_variants SET
        sku              = coalesce(v_var->>'sku', sku),
        name             = coalesce(v_var->>'name', name),
        price            = coalesce((v_var->>'price')::numeric, price),
        cost_price       = coalesce((v_var->>'cost_price')::numeric, cost_price),
        compare_at_price = coalesce((v_var->>'compare_at_price')::numeric, compare_at_price),
        stock_quantity   = coalesce((v_var->>'stock_quantity')::int, stock_quantity),
        reorder_level    = coalesce((v_var->>'reorder_level')::int, reorder_level),
        is_active        = coalesce((v_var->>'is_active')::boolean, is_active),
        updated_at       = now()
      WHERE id = (v_var->>'id')::uuid;
    ELSE
      INSERT INTO product_variants (
        product_id, sku, name, price, cost_price, compare_at_price,
        stock_quantity, reorder_level, is_active
      )
      VALUES (
        v_id,
        v_var->>'sku',
        coalesce(v_var->>'name', 'Default'),
        (v_var->>'price')::numeric,
        (v_var->>'cost_price')::numeric,
        (v_var->>'compare_at_price')::numeric,
        coalesce((v_var->>'stock_quantity')::int, 0),
        coalesce((v_var->>'reorder_level')::int, 5),
        coalesce((v_var->>'is_active')::boolean, true)
      );
    END IF;
  END LOOP;

  FOR v_img IN SELECT * FROM jsonb_array_elements(p_images)
  LOOP
    INSERT INTO product_images (product_id, variant_id, storage_path, alt_text, sort_order, is_main)
    VALUES (
      v_id,
      NULLIF(v_img->>'variant_id','')::uuid,
      v_img->>'storage_path',
      v_img->>'alt_text',
      coalesce((v_img->>'sort_order')::int, 0),
      coalesce((v_img->>'is_main')::boolean, false)
    );
  END LOOP;

  RETURN v_id;
END;
$$;

-- Delivery zones: schema column is delivery_fee, and there is no
-- `districts` column (only `notes`).
CREATE OR REPLACE FUNCTION admin_create_delivery_zone(
  p_name text,
  p_delivery_fee numeric,
  p_estimated_days int DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO delivery_zones (name, delivery_fee, estimated_days, notes, is_active)
  VALUES (p_name, p_delivery_fee, p_estimated_days, p_notes, true)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Couriers: no delivery_partner_id column in the base schema (couriers
-- and delivery_partners are independent tables joined via shipments).
CREATE OR REPLACE FUNCTION admin_create_courier(
  p_full_name text,
  p_phone text,
  p_vehicle_type text DEFAULT NULL,
  p_operating_area text DEFAULT NULL,
  p_commission_rate numeric DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO couriers (
    full_name, phone, vehicle_type, operating_area, commission_rate, is_active
  )
  VALUES (
    p_full_name, p_phone, p_vehicle_type, p_operating_area, p_commission_rate, true
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
