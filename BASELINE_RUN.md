# Nile Tropical Baseline Run

This package is the frontend baseline for the existing Nile Tropical Supabase project.

## Important
- Do NOT deploy `supabase/functions/payment-*` from this repository over the live payment-initiate/payment-status/payment-webhook functions.
- The live payment transport uses the Oracle fixed-egress MTN gateway.
- Secrets must never be committed to this repository.

## Run on Windows
```powershell
cd nile_tropical
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define=APP_ENV=development
```

For a real Supabase environment, provide the existing public Supabase URL and anon key using `--dart-define`; never use service-role keys in Flutter.

## Current known non-blocking TODOs
- Real notification providers (SMS/WhatsApp/email/push).
- Advanced CMS editors.
- Further report aggregation optimization.
- Production-grade E2E testing across auth, order, payment, delivery, POD and COD.
