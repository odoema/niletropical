-- Nile Tropical production image audit
-- READ-ONLY. Safe to run in Supabase SQL Editor.
-- Project: ououfhsswyqutcczdtnb
--
-- Purpose:
--   1. Confirm the production catalogue still exists.
--   2. Show product_images references.
--   3. Identify references whose storage object is missing.
--   4. Identify active products with no image reference.
--   5. Confirm the product-images bucket exists and is public.
--
-- IMPORTANT: This script performs SELECTs only. It does not insert,
-- update, delete, create, rename, or upload anything.

-- A. Storage bucket contract
select
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
from storage.buckets
where id = 'product-images';

-- B. Catalogue totals
select
  (select count(*) from public.products) as products_total,
  (select count(*) from public.products
    where is_active = true and deleted_at is null) as active_products,
  (select count(*) from public.product_images) as product_image_rows,
  (select count(*) from storage.objects
    where bucket_id = 'product-images') as storage_objects;

-- C. Every product image reference and whether the Storage object exists
select
  p.id as product_id,
  p.name as product_name,
  p.slug,
  pi.id as product_image_id,
  pi.storage_path,
  pi.is_main,
  pi.sort_order,
  case
    when o.id is not null then true
    else false
  end as storage_object_exists,
  o.name as storage_object_name
from public.products p
left join public.product_images pi
  on pi.product_id = p.id
left join storage.objects o
  on o.bucket_id = 'product-images'
 and o.name = pi.storage_path
where p.deleted_at is null
order by p.name, pi.sort_order, pi.created_at;

-- D. Active products with no product_images row
select
  p.id,
  p.name,
  p.slug,
  p.is_featured,
  p.is_bestseller,
  p.is_new,
  p.is_promotional
from public.products p
where p.is_active = true
  and p.deleted_at is null
  and not exists (
    select 1
    from public.product_images pi
    where pi.product_id = p.id
  )
order by p.created_at desc;

-- E. Product-image rows whose referenced object is missing
select
  pi.id as product_image_id,
  pi.product_id,
  p.name as product_name,
  p.slug,
  pi.storage_path,
  pi.is_main,
  pi.sort_order
from public.product_images pi
join public.products p
  on p.id = pi.product_id
left join storage.objects o
  on o.bucket_id = 'product-images'
 and o.name = pi.storage_path
where o.id is null
order by p.name, pi.sort_order;

-- F. Actual files currently present in product-images
select
  name,
  id,
  created_at,
  updated_at,
  last_accessed_at,
  metadata
from storage.objects
where bucket_id = 'product-images'
order by name;
