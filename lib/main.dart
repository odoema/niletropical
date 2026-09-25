/// Nile Tropical Uganda
/// Digital Commerce & Operations Platform
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'shared/services/supabase_service.dart';
import 'shared/services/push_notification_service.dart';
import 'shared/services/auth_service.dart';
import 'shared/widgets/push_notification_prompt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fails fast in staging/production if credentials are missing rather than
  // silently running the whole app on mock data. Development may proceed
  // unconfigured while no Supabase project exists yet.
  Env.assertConfiguredOrThrow();

  if (Env.isConfigured) {
    await SupabaseService.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    await PushNotificationService.syncIfGranted();
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        // Link the authenticated Google identity to the existing commerce
        // customer first, then synchronize the browser push subscription.
        Future<void>(() async {
          await AuthService.linkExistingCustomer();
          await PushNotificationService.syncIfGranted();
        });
      }
    });
  } else if (kDebugMode) {
    debugPrint(
      '[Nile Tropical] SUPABASE_URL/SUPABASE_ANON_KEY not set — running '
      'in development with mock/seed data only. See lib/core/config/env.dart.',
    );
  }

  runApp(
    const ProviderScope(
      child: NileTropicalApp(),
    ),
  );
}

class NileTropicalApp extends StatelessWidget {
  const NileTropicalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      builder: (context, child) => PushNotificationPrompt(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
