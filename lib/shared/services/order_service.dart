/// Nile Tropical - Order Service
/// Server-side order creation and tracking.
///
/// Tracking intentionally uses the track-order Edge Function instead of the
/// legacy track_order SQL RPC. The live database uses customer_phone_snapshot,
/// and the Edge Function gives us one canonical production tracking path.

import 'package:uuid/uuid.dart';

import '../models/cart.dart';
import 'supabase_service.dart';
import '../../core/config/env.dart';

class OrderService {
  static final _uuid = Uuid();

  static Future<Map<String, dynamic>> createOrder({
    required Cart cart,
    required String fullName,
    required String phone,
    String? email,
    required String address,
    required String deliveryZoneId,
    required String paymentMethod,
    String? notes,
    String? idempotencyKey,
    String? couponCode,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();

    final items = cart.items
        .map(
          (i) => {
            'variant_id': i.variant.id,
            'quantity': i.quantity,
          },
        )
        .toList();

    if (!Env.isConfigured) {
      final orderNumber =
          'NTI-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';

      return {
        'order_id': key,
        'order_number': orderNumber,
        'total': cart.subtotal + 5000,
        'idempotent': false,
      };
    }

    final res = await SupabaseService.client.rpc(
      'create_order',
      params: {
        'p_idempotency_key': key,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_email': email,
        'p_address': address,
        'p_delivery_zone_id': deliveryZoneId,
        'p_payment_method': paymentMethod,
        'p_items': items,
        'p_notes': notes,
      },
    );

    return Map<String, dynamic>.from(res as Map);
  }

  /// Track an order by its displayed order number or a legacy database UUID.
  /// The Edge Function resolves the UUID when necessary and verifies the
  /// checkout phone against the canonical customer_phone_snapshot.
  static Future<Map<String, dynamic>?> trackOrder({
    required String orderNumber,
    required String phone,
  }) async {
    if (!Env.isConfigured) {
      return {
        'found': true,
        'order_number': orderNumber,
        'status': 'processing',
        'payment_status': 'paid',
        'total': 0,
        'timeline': [
          {
            'status': 'new_order',
            'note': 'Order created',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'status': 'processing',
            'note': 'Being prepared',
            'created_at': DateTime.now().toIso8601String(),
          },
        ],
        'shipment': null,
      };
    }

    final response = await SupabaseService.client.functions.invoke(
      'track-order',
      body: {
        'order_number': orderNumber,
        'phone': phone,
      },
    );

    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw StateError('track-order returned an unexpected payload');
  }
}
