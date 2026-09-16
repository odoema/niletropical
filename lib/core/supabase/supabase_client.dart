import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static Future<void> initialize() async {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: publishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}