# Exact integration — Gaps A, B, C (Nile-styled)

## 1. Copy these files into your project

```
lib/shared/services/customer_admin_service.dart
lib/shared/services/cod_service.dart
lib/shared/services/pod_upload_service.dart

lib/admin/customers/customers_screen.dart
lib/admin/customers/customer_detail_screen.dart
lib/admin/finance/cod_reconciliation_screen.dart
lib/admin/delivery/proof_of_delivery_screen.dart
```

(Create the folders if they do not exist.)

## 2. GoRouter — add these routes inside your existing Admin shell

Find the admin `ShellRoute` (or the block that already has `/admin/orders`, `/admin/delivery`, etc.) and add:

```dart
// --- Customers (Gap #2) ---
GoRoute(
  path: '/admin/customers',
  name: 'admin-customers',
  builder: (context, state) => const CustomersScreen(),
  routes: [
    GoRoute(
      path: ':id',
      name: 'admin-customer-detail',
      builder: (context, state) => CustomerDetailScreen(
        customerId: state.pathParameters['id']!,
      ),
    ),
  ],
),

// --- COD Reconciliation (Gap #3) ---
GoRoute(
  path: '/admin/finance/cod',
  name: 'admin-cod',
  builder: (context, state) => const CodReconciliationScreen(),
),
```

Import the screens at the top of the router file:

```dart
import 'package:nile_tropical/admin/customers/customers_screen.dart';
import 'package:nile_tropical/admin/customers/customer_detail_screen.dart';
import 'package:nile_tropical/admin/finance/cod_reconciliation_screen.dart';
import 'package:nile_tropical/admin/delivery/proof_of_delivery_screen.dart';
```

## 3. Admin navigation entries

In your Admin side nav / bottom nav / dashboard quick-actions, add:

```dart
// Customers
NavigationDestination / ListTile(
  icon: Icons.people_outline,
  label: 'Customers',
  onTap: () => context.go('/admin/customers'),
)

// COD (under Finance or Delivery section)
NavigationDestination / ListTile(
  icon: Icons.payments_outlined,
  label: 'COD Reconciliation',
  onTap: () => context.go('/admin/finance/cod'),
)
```

## 4. Wire POD photo capture from shipment detail

In the existing shipment detail / courier action screen, replace or add the POD button:

```dart
FilledButton.icon(
  icon: const Icon(Icons.camera_alt),
  label: const Text('Proof of Delivery'),
  onPressed: () async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProofOfDeliveryScreen(
          shipmentId: shipment['id'] as String,
          orderId: shipment['order_id'] as String?,
          isCod: orderPaymentMethod == 'cash_on_delivery',
          outstandingAmount: orderTotal, // optional
        ),
      ),
    );
    if (result == true) {
      // refresh shipment / order
    }
  },
)
```

## 5. Device permissions (if not already present)

**Android** `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Take a photo as proof of delivery.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose a delivery photo.</string>
```

## 6. Verify storage bucket

Confirm in Supabase Dashboard → Storage:
- Bucket id: `proof-of-delivery` (private)
- Staff / courier can INSERT objects under that bucket

## 7. After copy + wiring

```bat
cd /d "C:\Users\odoem\Downloads\Susan\Betty\now\nile_tropical"
flutter pub get
flutter analyze
flutter run -d chrome --dart-define=APP_ENV=development
```

Smoke-test:
1. Admin → Customers → search → open detail → change status
2. Admin → COD Reconciliation → record a collection
3. Courier/staff shipment → Take photo → Submit POD

## 8. Update tracker

In `GAPS_TRACKER.md` set:

| # | Status |
|---|--------|
| 2 | **Done** |
| 3 | **Done** |
| 4 | **Done** |

Add log line:
```
- 2026-09-16 — Gaps #2 #3 #4 closed: Customers admin, COD reconciliation, POD photo capture.
```
