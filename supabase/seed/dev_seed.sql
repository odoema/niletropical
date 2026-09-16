-- Nile Tropical Uganda — DEVELOPMENT SEED DATA
-- DO NOT RUN AGAINST PRODUCTION. This is local/dev-only content, mirroring
-- the mock arrays that used to live inside product_provider.dart,
-- delivery_service.dart and inventory_service.dart (per the audit's Phase 0
-- instruction: separate dev seed data from production data instead of
-- deleting it).
--
-- Run locally with:
--   supabase db reset          (applies migrations then this seed), or
--   psql "$DATABASE_URL" -f supabase/seed/dev_seed.sql

-- ---------------------------------------------------------------------
-- Products (from product_provider.dart's _mockProducts — real Nile
-- Tropical catalogue items per the Flutterwave store reference, not
-- invented data)
-- ---------------------------------------------------------------------
insert into products (id, name, slug, short_description, full_description, benefits, how_to_use, brand, is_featured, is_bestseller, is_new, is_promotional)
values
  ('00000000-0000-0000-0000-000000000001', 'E.C.O Shea Butter', 'eco-shea-butter',
   '100% pure natural shea butter. Rich in vitamins A, E & F.',
   'Carefully sourced and processed to retain natural goodness. Ideal for deep moisturising of skin and hair.',
   E'• Deeply moisturises\n• Rich in vitamins A, E & F\n• Improves skin elasticity\n• Natural & eco-friendly',
   'Apply a small amount to clean skin and massage gently. Suitable for face, body and hair.',
   'Nile Tropical', true, true, false, false),
  ('00000000-0000-0000-0000-000000000002', 'White Nile Shea Butter', 'white-nile-shea-butter',
   'Gentle shea butter lotion, perfect for baby care.',
   'Soft, nourishing formula specially crafted for sensitive skin.',
   null, null, 'Nile Tropical', true, false, true, false),
  ('00000000-0000-0000-0000-000000000003', 'Nile Liquid Hand Sanitizer', 'nile-hand-sanitizer',
   'Effective hand sanitizer available in multiple sizes.',
   null, null, null, 'Nile Tropical', true, false, false, false),
  ('00000000-0000-0000-0000-000000000004', 'Hibiscus Tea', 'hibiscus-tea',
   'Natural hibiscus tea – 150g.',
   null, null, null, 'Nile Tropical', true, false, false, true),
  ('00000000-0000-0000-0000-000000000005', 'Hand Sanitizer Gel', 'hand-sanitizer-gel',
   'Convenient 50ml gel sanitizer.',
   null, null, null, 'Nile Tropical', false, false, false, false);

insert into product_variants (id, product_id, sku, name, price, compare_at_price, stock_quantity, reorder_level)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'ECO-SB-250', '250g', 10000, 16000, 45, 20),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'ECO-SB-500', '500g', 18000, 25000, 28, 10),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 'WN-SB-250', '250ml', 10000, null, 60, 10),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', 'NHS-500', '500ml', 5000, null, 120, 20),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000003', 'NHS-1000', '1 Litre', 8000, null, 80, 15),
  ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000003', 'NHS-5000', '5 Litres', 10000, null, 25, 5),
  ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000004', 'HT-150', '150g', 10000, null, 40, 10),
  ('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000005', 'HSG-50', '50ml', 5000, null, 200, 20);

-- ---------------------------------------------------------------------
-- Delivery zones/partners/couriers (from delivery_service.dart's
-- _mockZones/_mockPartners/_mockCouriers)
-- ---------------------------------------------------------------------
insert into delivery_zones (name, delivery_fee, estimated_days, notes) values
  ('Kampala', 5000, 1, null),
  ('Wakiso', 7000, 1, null),
  ('Entebbe', 8000, 1, null),
  ('Jinja', 12000, 2, null),
  ('Gulu', 15000, 3, null),
  ('Mbarara', 15000, 3, null),
  ('Other / Outside', 10000, 4, 'Fee may vary by exact destination');

insert into delivery_partners (name, type, contact_person, phone, terminal, routes) values
  ('Kampala Coach', 'bus', 'James Okello', '+256700111222', 'Kampala Bus Terminal', array['Kampala', 'Jinja', 'Mbale']),
  ('Link Bus', 'bus', 'Sarah Nalubega', '+256700333444', 'New Bus Park', array['Kampala', 'Gulu', 'Arua']),
  ('Safe Boda Partners', 'boda', 'Dispatch Desk', '+256700555666', null, array['Kampala', 'Wakiso', 'Entebbe']);

insert into couriers (full_name, phone, vehicle_type, registration_number, operating_area, commission_rate) values
  ('Peter Mugisha', '+256772111222', 'Motorcycle', 'UBD 123A', 'Kampala Central', 15),
  ('Grace Achieng', '+256753333444', 'Motorcycle', 'UBE 456B', 'Nakawa / Ntinda', 15);

-- ---------------------------------------------------------------------
-- Opening stock movements so the numbers above reconcile with a real
-- audit trail rather than appearing from nowhere.
-- ---------------------------------------------------------------------
insert into stock_movements (product_variant_id, movement_type, quantity, reference, notes)
select id, 'opening', stock_quantity, 'DEV-SEED', 'Development seed opening balance'
from product_variants;
