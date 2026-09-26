import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'supabase_service.dart';
import '../../core/config/env.dart';

class NotificationInboxService {
  static Future<List<Map<String, dynamic>>> fetch({int limit = 50}) async {
    if (!Env.isConfigured || AuthService.user == null) return const [];

    final customer = await SupabaseService.client
        .from('customers')
        .select('id')
        .eq('user_id', AuthService.user!.id)
        .maybeSingle();

    final customerId = customer?['id']?.toString();
    if (customerId == null || customerId.isEmpty) return const [];

    final rows = await SupabaseService.client
        .from('notification_logs')
        .select('id, order_id, event_key, status, created_at')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Resolve the canonical public order identity used by the tracking screen.
  /// customer_phone_snapshot is the phone captured at checkout and remains
  /// stable even if the customer's profile changes later.
  static Future<Map<String, dynamic>?> orderIdentity(String orderId) async {
    if (!Env.isConfigured || AuthService.user == null) return null;

    final row = await SupabaseService.client
        .from('orders')
        .select('id, order_number, customer_phone_snapshot')
        .eq('id', orderId)
        .maybeSingle();

    return row == null ? null : Map<String, dynamic>.from(row);
  }

  static String titleFor(String event) {
    switch (event) {
      case 'order_received':
        return 'Order received';
      case 'order_confirmed':
        return 'Order confirmed';
      case 'payment_confirmed':
        return 'Payment confirmed';
      case 'dispatched':
        return 'Order dispatched';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Order delivered';
      case 'order_cancelled':
        return 'Order cancelled';
      default:
        return 'Nile Tropical update';
    }
  }

  static String messageFor(String event) {
    switch (event) {
      case 'order_received':
        return 'We have received your order. Thank you for shopping with us.';
      case 'order_confirmed':
        return 'Your order has been confirmed and is being prepared.';
      case 'payment_confirmed':
        return 'Your payment has been confirmed. We are preparing your items.';
      case 'dispatched':
        return 'Your order has been dispatched and is on its way.';
      case 'out_for_delivery':
        return 'Your order is now out for delivery.';
      case 'delivered':
        return 'Your order has been delivered. Thank you for shopping with Nile Tropical!';
      case 'order_cancelled':
        return 'Your order has been cancelled. Please contact us if you need assistance.';
      default:
        return 'There is a new update on your order.';
    }
  }

  static IconData iconFor(String event) {
    switch (event) {
      case 'order_received':
        return Icons.receipt_long_rounded;
      case 'order_confirmed':
        return Icons.verified_rounded;
      case 'payment_confirmed':
        return Icons.payments_rounded;
      case 'dispatched':
        return Icons.local_shipping_rounded;
      case 'out_for_delivery':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'order_cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  static bool isPositive(String event) =>
      event == 'order_received' ||
      event == 'order_confirmed' ||
      event == 'payment_confirmed' ||
      event == 'dispatched' ||
      event == 'out_for_delivery' ||
      event == 'delivered';
}
