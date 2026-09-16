# Storage

Apply `migrations/025_storage.sql` in the Supabase SQL editor **after** checking Dashboard → Storage for existing bucket ids.

| Bucket | Public | Writers | Readers |
|---|---|---|---|
| product-images | yes | `is_staff()` | anyone |
| cms | yes | `is_staff()` | anyone |
| pod | no | staff or active courier | same |

Store object **keys** in `storage_path` / `photo_storage_path` / `image_storage_path`.  
Resolve display URLs in Flutter:

- public buckets → `storage.from(bucket).getPublicUrl(path)`
- `pod` → `createSignedUrl(path, 300)`

If live buckets already exist under other names, edit only the `bucket_id` literals in 025. Do not rename Postgres columns.
