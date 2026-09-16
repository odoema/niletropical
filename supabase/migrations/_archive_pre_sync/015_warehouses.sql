-- 015_warehouses.sql — multi-warehouse stock (§26)
-- Additive; keeps product_variants.stock_quantity as denormalised cache.

CREATE TABLE IF NOT EXISTS warehouses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  address text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO warehouses (code, name, is_default)
VALUES ('NEBBI_MAIN', 'Nebbi Main', true)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS warehouse_stock (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id uuid NOT NULL REFERENCES warehouses(id),
  product_variant_id uuid NOT NULL REFERENCES product_variants(id),
  quantity integer NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  reserved integer NOT NULL DEFAULT 0 CHECK (reserved >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (warehouse_id, product_variant_id)
);

CREATE TABLE IF NOT EXISTS stock_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id uuid NOT NULL REFERENCES warehouses(id),
  product_variant_id uuid NOT NULL REFERENCES product_variants(id),
  order_id uuid REFERENCES orders(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'released', 'consumed')),
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_warehouse_stock_variant ON warehouse_stock(product_variant_id);
CREATE INDEX IF NOT EXISTS idx_stock_reservations_order ON stock_reservations(order_id);
