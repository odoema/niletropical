# Current status (latest zip)

This file supersedes the older P3–P10 checkboxes in README/CHANGES_FULL.

| Area | State |
|---|---|
| Shells + GoRouter | Done |
| Auth + admin/courier guards | Done (verify live roles) |
| Catalogue read, search, flags | Done |
| Cart | Done (local) |
| create_order + zones | Done |
| Payment initiate/status UI | Done — calls **live** functions |
| Tracking | Done |
| Customer orders by customer_id | Done |
| Addresses add (no fake phone) | Done |
| Product upsert + extra fields | Done; variants expandable |
| Courier own shipments | Done |
| POD RPC | Done; camera upload still manual path |
| CMS two-field CRUD | Done |
| Storage policies 025 | In repo; apply after checking bucket ids |
| Notifications | Stub only |
| flutter analyze/test/build | Not certified in this environment |

**Do not deploy** `supabase/functions/payment-*` over live v13 / v5–v6 / v10–v11.

- image_picker + MediaUpload on product form and courier POD
- address default/delete
- shop in-stock filter
- AppColors usages aliased to NileColors in admin screens
