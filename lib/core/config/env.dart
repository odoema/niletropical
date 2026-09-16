/// Nile Tropical - Environment Configuration
/// Copyright © Hon. Dr. Betty Udongo Pacutho
///
/// Reads Supabase credentials from compile-time environment variables.
/// NEVER hard-code real credentials here — they are injected at build/run
/// time via --dart-define or --dart-define-from-file so they can differ
/// between development, staging, and production without touching code.
///
/// Usage:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxx \
///     --dart-define=APP_ENV=development
///
/// Or maintain per-environment files (not committed) and run with:
///   flutter run --dart-define-from-file=env/dev.json
///   flutter run --dart-define-from-file=env/prod.json
library;

enum AppEnvironment { development, staging, production }

class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String _envName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get environment {
    switch (_envName) {
      case 'production':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isDevelopment => environment == AppEnvironment.development;

  /// True once real Supabase credentials have been provided. Used to decide
  /// whether to initialize Supabase at all, and whether services are
  /// permitted to fall back to mock/seed data.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Fails fast in production/staging if credentials are missing, instead of
  /// silently running the whole app on mock data (see AUDIT.md §"no fake
  /// success"). Development is allowed to proceed unconfigured so the app
  /// can still run against local mock data before a Supabase project exists.
  static void assertConfiguredOrThrow() {
    if (isConfigured) return;
    if (isDevelopment) return;
    throw StateError(
      'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define '
      'for the $_envName environment. Refusing to start with no backend '
      'configured outside of development.',
    );
  }
}
