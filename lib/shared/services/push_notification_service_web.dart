/// Nile Tropical free Web Push client.
/// Uses standards-based Web Push/VAPID; no paid messaging provider.

import 'dart:convert';
import 'dart:js_interop';

import '../../core/config/env.dart';
import 'supabase_service.dart';

const _publicVapidKey =
    'BHF9yxwTcIkl7opt5_yjvXYont8di_WhN_Q5TJpQ_uha6rxQsr82q4Cbyy2jFggRGGME6Yb3-F456LR9SNTbJ30';

@JS('nilePushPermission')
external JSString nilePushPermission();

@JS('nilePushSubscribe')
external JSPromise<JSString?> nilePushSubscribe();

class PushNotificationService {
  static const bool isSupported = true;

  static String get permission {
    try {
      return nilePushPermission().toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  static Future<void> syncIfGranted() async {
    if (!Env.isConfigured) return;
    final user = SupabaseService.client.auth.currentUser;
    if (user == null || permission != 'granted') return;

    try {
      await _saveSubscription(user.id);
    } catch (error) {
      debugPrint('[Push] Existing permission sync failed: $error');
    }
  }

  static Future<bool> enable() async {
    if (!Env.isConfigured) return false;

    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return false;

    try {
      final raw = await nilePushSubscribe().toDart;
      if (raw == null) return false;

      final subscription =
          Map<String, dynamic>.from(jsonDecode(raw.toDart) as Map);

      final endpoint = subscription['endpoint']?.toString();
      final keys = Map<String, dynamic>.from(
        (subscription['keys'] as Map?) ?? const {},
      );

      final p256dh = keys['p256dh']?.toString();
      final auth = keys['auth']?.toString();

      if (endpoint == null || p256dh == null || auth == null) {
        return false;
      }

      await SupabaseService.client.from('push_subscriptions').upsert(
        {
          'customer_id': user.id,
          'endpoint': endpoint,
          'p256dh': p256dh,
          'auth': auth,
          'user_agent': 'Nile Tropical Web',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'endpoint',
      );

      return true;
    } catch (error) {
      debugPrint('[Push] Enable failed: $error');
      return false;
    }
  }

  static Future<void> _saveSubscription(String customerId) async {
    final raw = await nilePushSubscribe(_publicVapidKey.toJS).toDart;
    if (raw == null) return;

    final subscription =
        Map<String, dynamic>.from(jsonDecode(raw.toDart) as Map);
    final keys = Map<String, dynamic>.from(
      (subscription['keys'] as Map?) ?? const {},
    );

    await SupabaseService.client.from('push_subscriptions').upsert(
      {
        'customer_id': customerId,
        'endpoint': subscription['endpoint'],
        'p256dh': keys['p256dh'],
        'auth': keys['auth'],
        'user_agent': 'Nile Tropical Web',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'endpoint',
    );
  }
}

void debugPrint(String message) => print(message);
