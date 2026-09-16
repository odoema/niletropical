/// Payment initiation + status via Edge Functions.
/// The client never talks to MTN/Airtel and is never payment authority.
import 'supabase_service.dart';
import '../../core/config/env.dart';
import '../../core/constants/payment_methods.dart';

class PaymentService {
  static Future<Map<String, dynamic>> initiate({
    required String orderId,
    required String method,
    String? phone,
  }) async {
    final normalized = PaymentMethods.normalize(method);
    if (!Env.isConfigured) {
      return {
        'reference': 'DEV-MOCK-${DateTime.now().millisecondsSinceEpoch}',
        'status': 'pending',
        'order_id': orderId,
        'method': normalized,
        'instructions': PaymentMethods.isMobileMoney(normalized)
            ? 'Approve the prompt on your phone (dev mock)'
            : 'Complete payment (dev mock)',
      };
    }
    final res = await SupabaseService.client.functions.invoke(
      'payment-initiate',
      body: {
        'order_id': orderId,
        'method': normalized,
        'phone': phone,
      },
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('payment-initiate returned unexpected payload');
  }

  static Future<Map<String, dynamic>> status(String reference) async {
    if (!Env.isConfigured) {
      // Stay pending in mock so the UI can exercise the waiting path.
      return {'reference': reference, 'status': 'pending'};
    }
    final res = await SupabaseService.client.functions.invoke(
      'payment-status',
      body: {'reference': reference},
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('payment-status returned unexpected payload');
  }
}
