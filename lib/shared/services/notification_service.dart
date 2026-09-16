/// Nile Tropical - Notification Service
/// Copyright © Hon. Dr. Betty Udongo Pacutho
/// Provider-agnostic architecture for SMS, WhatsApp, Email, Push

enum NotificationChannel { sms, whatsapp, email, push }

class NotificationService {
  /// Send order-related notification to customer
  static Future<void> sendOrderNotification({
    required String phone,
    required String orderNumber,
    required String event,
    String? extraMessage,
  }) async {
    final message = _buildMessage(orderNumber, event, extraMessage);

    // TODO: Integrate real providers
    // - SMS: Africa's Talking / Twilio / local gateway
    // - WhatsApp: WhatsApp Business API / provider
    // - Email: Supabase Edge Function + Resend / SendGrid
    // - Push: Firebase Cloud Messaging

    debugPrint('[Notification] To: $phone | $message');
  }

  static String _buildMessage(String orderNumber, String event, String? extra) {
    switch (event) {
      case 'order_received':
        return 'Your Nile Tropical order $orderNumber has been received. Thank you!';
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
      default:
        return extra ?? 'Update on your Nile Tropical order $orderNumber.';
    }
  }

  /// Staff alert helper
  static Future<void> notifyStaff({
    required String event,
    required String orderNumber,
  }) async {
    debugPrint('[Staff Alert] $event — $orderNumber');
    // TODO: Push to admin devices / email / Slack-style webhook
  }
}

void debugPrint(String message) {
  // Simple console log for development
  print(message);
}
