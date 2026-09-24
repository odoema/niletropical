# Nile Tropical — Product Image Matching Report

Date: 2026-09-24

The 49 supplied original photographs were reviewed using OCR plus visual verification against the 20-product catalogue in `assets/products/manifest.json`.

## High-confidence exact matches

| Catalogue slug | Original photograph | Evidence |
|---|---|---|
| nile-sheabutter-lotion-apple-200ml | Nile products Edits-23.jpg | OCR reads APPLE and 200 ML |
| nile-sheabutter-lotion-lavender-200ml | Nile products Edits-29.jpg | OCR reads LAVENDER and 200 ML |
| nile-sheabutter-lotion-lemon-200ml | Nile products Edits-25.jpg | Visual label reads LEMON and 200 ML |
| shea-butter-mosquito-repellent-jelly-150g | Nile products Edits-78.jpg | OCR/visual reads SHEA BUTTER Mosquito Repellent |
| sheabutter-facial-scrub-soap-120g | Nile products Edits-98.jpg | Visual label identifies Facial scrub soap |
| tropisun-sunscreen-for-albinism-200g | Nile products Edits-17.jpg | OCR/visual identifies TROPI/SUN sunscreen formulation |
| hibiscus-powder-150g | Nile products Edits-63.jpg | Visual package is the hibiscus product; OCR reads 150g |

## Newly confirmed catalogue-adjacent evidence

OCR also established several supplied photographs that are **not** the same size/product records as the current 20-product catalogue and therefore must not be substituted into those records:

- Edits-8.jpg = Apple lotion 100 ML.
- Edits-10.jpg and Edits-2026.jpg = Lavender lotion 100 ML.
- Edits-15.jpg, Edits-19.jpg and Edits-21.jpg = 400 ML lotion variants.
- Edits-43.jpg = Apple lotion tube, 50 ML.
- Edits-44.jpg = another 50 ML lotion tube variant.
- Edits-30.jpg, Edits-33.jpg and Edits-35.jpg are hair-care products, not catalogue lotion records.
- Edits-67.jpg and Edits-76.jpg are mosquito-repellent variants/alternate packaging; the exact 150g catalogue identity remains tied to Edits-78.jpg.
- Edits-87.jpg and Edits-89.jpg are Shea Butter Lip Balm, not the catalogue soap products.
- Edits-91.jpg and Edits-93.jpg are Pure Shea Butter, not the E.C.O. Shea Butter records.
- Edits-74.jpg is Man Power Herbal Tea.

## Additional evidence

- Edits-79.jpg is an alternate view of the mosquito repellent.
- Edits-12.jpg and Edits-37.jpg are alternate views of the Tropisun sunscreen.
- Edits-53.jpg is clearly E.C.O. Shea, but the photograph explicitly shows 100g while the catalogue entry has no size.
- E.C.O. Shea photographs Edits-55.jpg and Edits-61.jpg are retained as size-verification candidates for the 250g and 500g catalogue records.

## Deliberately not auto-matched

The supplied photographs did not provide a sufficiently reliable exact match for the four sanitizer records, Sweetie 200ml lotion, baby lotion 200ml, the three remaining soap records, or Hibiscus Tea 150g.

This is intentional: uncertain photographs are not being assigned to the wrong catalogue product.

## Next production step

Only the high-confidence matches should replace the SVG placeholders. The original JPEG filenames remain authoritative and must not be renamed destructively.
