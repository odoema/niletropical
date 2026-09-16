# Nile Tropical — Release Baseline

Base: nile_tropical_working + verified frontend fixes.

## Fixed in this baseline
- Product cards resolve Supabase Storage paths to public URLs.
- Home and Shop product grids adapt to available width.
- Courier shipment detail requires a linked courier profile and matching shipment assignment.
- Product image uploads do not duplicate the storage bucket name in the object path.
- Admin mock order data uses canonical `mtn_momo` payment method.
- Updated typography/tests from the latest patch are included.

## Live backend contract
- `create_order()` remains authoritative for orders, prices, delivery fee, stock reservations and totals.
- Live payment functions are deployed separately; DO NOT deploy the local copies in `supabase/functions/payment-*` over the live versions.
- Live MTN path: Flutter → payment-initiate → Oracle fixed-egress gateway → MTN → payment-status/webhook.

## Verification status
- Archive integrity: verified.
- Local-import and asset-reference checks: verified.
- Flutter/Dart compile: NOT RUN here because the Flutter SDK is unavailable in this environment.
- Run on a machine with Flutter SDK before release: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run -d chrome`.
