/// Nile Tropical - Notification Service
/// Copyright © Hon. Dr. Betty Udongo Pacutho
/// Provider-agnostic notification queue for SMS, WhatsApp, Email and Push.
///
/// Order lifecycle events are queued by the database trigger in
/// supabase/migrations/20260925_notifications_production_wiring.sql.
/// This client service also exposes an explicit queue method for workflows
/// that need to create a notification outside the order trigger.

import '../../core/config/env.dart';
import 'supabase_service.dart';

enum NotificationChannel { sms, whatsapp, email, push }

class NotificationService {
  /// Queue an order-related notification in the production notification
  /// tables. Delivery is intentionally provider-agnostic: a dispatcher
  /// consumes notification_logs with status = 'queued' and updates the log
  /// after the external provider accepts/delivers the message.
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
        'p_fallback_message':
            fallbackMessage ?? _buildMessage('', event, null),
      },
    );

    return result?.toString();
  }

  /// Backward-compatible helper for order notification callers.
  ///
  /// If [orderId] is supplied, the notification is persisted to the
  /// production queue. Without an order id there is no safe public insert
  /// path, so the message is logged locally rather than bypassing RLS.
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

  /// Staff alert helper.
  ///
  /// Staff alerts remain provider-agnostic until an approved staff channel
  /// (email, WhatsApp, Slack, or push) is configured.
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
