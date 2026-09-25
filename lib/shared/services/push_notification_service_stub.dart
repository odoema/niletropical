/// Non-web implementation of the free Web Push service.
class PushNotificationService {
  static const bool isSupported = false;
  static String get permission => 'unsupported';

  static Future<void> syncIfGranted() async {}

  static Future<bool> enable() async => false;
}
