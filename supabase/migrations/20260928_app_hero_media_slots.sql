-- Store App HOME HERO 1-4 media slots.
-- Safe for existing installations: inserts missing slots only.
insert into public.website_media_slots (slot_key, label, storage_path, alt_text, is_active)
values
  ('app_hero_1', 'Store App HERO 1', 'products/eco-shea-butter-250g.svg', 'Nile Tropical Industries — Ugandan natural products brand', true),
  ('app_hero_2', 'Store App HERO 2', 'products/hibiscus-tea-150g.svg', 'From Uganda, With Purpose — natural ingredients and local production', true),
  ('app_hero_3', 'Store App HERO 3', 'products/nile-sheabutter-lotion-apple-200ml.svg', 'Natural Care For Everyday Living — personal care products', true),
  ('app_hero_4', 'Store App HERO 4', 'products/shea-butter-mosquito-repellent-jelly-150g.svg', 'Growing With Our Community — a modern Ugandan brand', true)
on conflict (slot_key) do nothing;