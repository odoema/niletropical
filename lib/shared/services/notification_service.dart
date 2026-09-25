/// Nile Tropical - Notification Service
/// Copyright © Hon. Dr. Betty Udongo Pacutho
/// Provider-agnostic notification queue for SMS, WhatsApp, Email and Push.
/// Order lifecycle notifications are persisted in notification_logs.

import '../../core/config/env.dart';
import 'supabase_service.dart';

enum NotificationChannel { sms, whatsapp, email, push }

class NotificationService {
  static Future<String?> queueOrderNotification({
    required String orderId,
    required String recipient,
    required String event,
    NotificationChannel channel = NotificationChannel.sms,
    String? fallbackMessage,
  }) async {
    if (!Env.isConfigured) {
      debugPrint('[Notification] Supabase not configured; skipped queue for $event.');
      return null;
    }

    final result = await SupabaseService.client.rpc(
      'queue_order_notification',
      params: {
        'p_order_id': orderId,
        'p_recipient': recipient,
        'p_channel': channel.name,
        'p_event_key': event,
        'p_fallback_message': fallbackMessage ?? _buildMessage('', event, null),
      },
    );

    return result?.toString();
  }

  static Future<void> sendOrderNotification({
    required String phone,
    required String orderNumber,
    required String event,
    String? extraMessage,
    String? orderId,
  }) async {
    final message = _buildMessage(orderNumber, event, extraMessage);

    if (orderId != null && orderId.isNotEmpty && Env.isConfigured) {
      await queueOrderNotification(
        orderId: orderId,
        recipient: phone,
        event: event,
        fallbackMessage: message,
      );
      return;
    }

    debugPrint('[Notification] $phone | $message');
  }

  static String _buildMessage(String orderNumber, String event, String? extra) {
    switch (event) {
      case 'order_received':
        return 'Your Nile Tropical order $orderNumber has been received. Thank you!';
      case 'order_confirmed':
        return 'Your Nile Tropical order $orderNumber has been confirmed and is being prepared.';
      case 'payment_confirmed':
        return 'Payment confirmed for order $orderNumber. We are preparing your items.';
      case 'dispatched':
        return 'Your order $orderNumber has been dispatched.';
      case 'arrived':
        return 'Your order $orderNumber has arrived at the destination terminal.';
      case 'out_for_delivery':
        return 'Your order $orderNumber is now out for delivery.';
      case 'delivered':
        return 'Your order $orderNumber has been delivered. Thank you for shopping with Nile Tropical!';
      case 'order_cancelled':
        return 'Your Nile Tropical order $orderNumber has been cancelled. Please contact us if you need assistance.';
      default:
        return extra ?? 'Update on your Nile Tropical order $orderNumber.';
    }
  }

  static Future<void> notifyStaff({
    required String event,
    required String orderNumber,
  }) async {
    debugPrint('[Staff Alert] $event — $orderNumber');
  }
}

void debugPrint(String message) {
  print(message);
}
