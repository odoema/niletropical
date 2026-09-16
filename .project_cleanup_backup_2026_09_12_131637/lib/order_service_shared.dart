/// Nile Tropical - Order Service
/// Aligned to create_order v2 (idempotency, server-side fee)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:uuid/uuid.dart';
import '../models/cart.dart';
import 'supabase_service.dart';
import '../../core/config/env.dart';

class OrderService {
  static final _uuid = Uuid();

  /// Create order via RPC create_order (p_idempotency_key, …)
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
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final items = cart.items
        .map((i) => {
              'variant_id': i.variant.id,
              'quantity': i.quantity,
            })
        .toList();

    if (!Env.isConfigured) {
      // Dev mock
      final orderNumber =
          'NTI-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
      return {
        'order_id': key,
        'order_number': orderNumber,
        'total': cart.subtotal + 5000,
        'idempotent': false,
      };
    }

    final res = await SupabaseService.client.rpc('create_order', params: {
      'p_idempotency_key': key,
      'p_full_name': fullName,
      'p_phone': phone,
      'p_email': email,
      // create_order expects p_address as a jsonb object keyed by
      // address_line (plus optional district/city/area/etc.) — a bare
      // string is valid jsonb but has no address_line key, which the
      // function reads as blank and rejects with "delivery address
      // required".
      'p_address': {'address_line': address},
      'p_delivery_zone_id': deliveryZoneId,
      'p_payment_method': paymentMethod,
      'p_items': items,
      'p_notes': notes,
    });
    return Map<String, dynamic>.from(res as Map);
  }

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
          {'status': 'new', 'note': 'Order created', 'created_at': DateTime.now().toIso8601String()},
          {'status': 'processing', 'note': 'Being prepared', 'created_at': DateTime.now().toIso8601String()},
        ],
        'shipment': null,
      };
    }
    final res = await SupabaseService.client.rpc('track_order', params: {
      'p_order_number': orderNumber,
      'p_phone': phone,
    });
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }
}
