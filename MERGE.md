# Merge strategy — Fixed4 + P1

## Rule
Fixed4 owns the **database contract**. P1 owns **storefront/ops UI**. Never replace Fixed4 migrations with P1 copies.

## Order
1. Start from Fixed4 (this tree).
2. Keep all of `supabase/migrations/` from Fixed4, including 016–024.
3. Keep Fixed4 Flutter that talks to those RPCs:
   - `product_form_screen.dart` (`full_description`, flags, cost, compare, reorder)
   - `delivery_service.dart` (`p_delivery_fee`, courier vehicle fields)
   - `proof_of_delivery_screen.dart` (`p_photo_storage_path`, `p_otp_or_signature`)
   - courier dashboard filter (`auth.uid` → `couriers.id` → `shipments.courier_id`)
4. Overlay P1 UI that Fixed4 lacked:
   - `cms_collection_screen.dart` + CMS routes
   - product image `PageView`
   - logo in customer shell / admin login
   - Nile-blue secondary/accent tokens
   - shipment detail actions (status + POD/COD), with RPC names rewritten to Fixed4
   - payment CTA “Check payment status”
   - no fabricated `0000000000` phone
5. Do **not** deploy `supabase/functions/payment-*` over live v13/v5/v10.

## Do not do
- Cherry-pick P1 `024_set_order_status.sql` or P1 `019` zone params (`p_fee` / `p_districts`).
- Stuff OTP into `p_photo_url`.
- Treat RLS as the only courier filter.

## Still after this merge
Camera → Storage upload, multi-variant editor, home CMS sections, notifications, `flutter analyze` / E2E.
