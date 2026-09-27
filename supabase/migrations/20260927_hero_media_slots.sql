-- Homepage HERO 1-4 CMS media slots.
-- Safe for existing installations: inserts missing slots only and preserves
-- any administrator-selected storage_path / alt_text on existing rows.

insert into public.website_media_slots (slot_key, label, storage_path, alt_text, is_active)
values
  ('hero_1', 'Homepage HERO 1', 'website/mozzie.jpg', 'Nile Tropical Shea Butter product in a natural setting', true),
  ('hero_2', 'Homepage HERO 2', null, 'Traditional processing of shea ingredients', true),
  ('hero_3', 'Homepage HERO 3', 'website/founder.jpg', 'African woman using a shea butter skincare product', true),
  ('hero_4', 'Homepage HERO 4', null, 'Women selling produce in a Ugandan market', true)
on conflict (slot_key) do nothing;
