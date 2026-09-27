# Nile Tropical SEO Standard

## Objective
Every public product and category must automatically receive a consistent SEO treatment from the authoritative Supabase catalogue. SEO must survive product additions, image changes, variant changes, pricing changes, category changes and deactivations without manual page editing.

## Canonical rules
- Public product URL: /products/{slug}/
- Public category URL: /categories/{slug}/
- One canonical URL per product.
- Product pages are generated from live public catalogue data at deployment time.
- ProductGroup + Product + Offer + BreadcrumbList structured data is generated automatically.
- Variant additions/removals are reflected automatically.
- Current price, currency and availability come from the authoritative variant records.
- Images are generated from the authoritative product image records.
- Image alt text uses stored alt_text when present; otherwise the generator derives a descriptive fallback from the product and variant.
- SEO title uses seo_title when present; otherwise "{Product Name} | Nile Tropical Uganda".
- SEO description uses seo_description when present, then short_description, then full_description, then a deterministic product/category fallback.
- No invented claims, ingredients, benefits, certifications, health claims, shipping promises, reviews or ratings.
- Out-of-stock products remain crawlable unless the business explicitly deactivates them.
- Deleted/inactive products are excluded from generated pages and sitemap.
- Prices are never hard-coded into SEO content.

## Deployment gates
The build must fail for:
- missing/duplicate active product slugs
- missing active product names
- active products without a valid category
- active variants without product, SKU or non-negative price
- duplicate active SKUs
- active product images without a valid product
- malformed image storage paths

The build must not fail merely because optional SEO copy is missing: deterministic defaults are supplied automatically.

## Change principle
The database remains the source of truth. The SEO layer is derived infrastructure, never a second catalogue.
