-- Nile Tropical: enforce one canonical main product image per product.
-- Existing data is repaired first. The canonical row is the existing main
-- image with the lowest sort_order, then oldest created_at, then id.
with ranked as (
  select
    pi.id,
    row_number() over (
      partition by pi.product_id
      order by pi.is_main desc, pi.sort_order asc, pi.created_at asc, pi.id asc
    ) as rn
  from public.product_images pi
)
update public.product_images pi
set is_main = (ranked.rn = 1)
from ranked
where pi.id = ranked.id
  and pi.is_main is distinct from (ranked.rn = 1);

create unique index if not exists ux_product_images_one_main
on public.product_images (product_id)
where is_main = true;

create index if not exists idx_product_images_product_main_sort
on public.product_images (product_id, is_main desc, sort_order asc, created_at asc);