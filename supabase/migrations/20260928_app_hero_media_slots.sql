-- Store App HOME HERO 1-4 media slots.
-- Custom storage_path is intentionally null so the Flutter app keeps its bundled
-- fallback artwork until an administrator replaces a slot.
insert into public.website_media_slots (slot_key, label, storage_path, alt_text, is_active)
values
  ('app_hero_1', 'Store App HERO 1', null, 'Nile Tropical Industries — Ugandan natural products brand', true),
  ('app_hero_2', 'Store App HERO 2', null, 'From Uganda, With Purpose — natural ingredients and local production', true),
  ('app_hero_3', 'Store App HERO 3', null, 'Natural Care For Everyday Living — personal care products', true),
  ('app_hero_4', 'Store App HERO 4', null, 'Growing With Our Community — a modern Ugandan brand', true)
on conflict (slot_key) do nothing;