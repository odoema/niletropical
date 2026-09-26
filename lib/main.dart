/// Nile Tropical Uganda
/// Digital Commerce & Operations Platform
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/errors/error_reporter.dart';
import 'core/router/app_router.dart';
import 'shared/services/supabase_service.dart';
import 'shared/services/auth_service.dart';

Future<void> main() async {
  return runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      ErrorReporter.captureFlutterError(details);
    };

    ui.PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter.captureAsyncError(error, stack);
      return true;
    };

    Env.assertConfiguredOrThrow();

    if (Env.isConfigured) {
      await SupabaseService.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
      SupabaseService.client.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          Future<void>(() async {
            try {
              await AuthService.linkExistingCustomer();
            } catch (e, stack) {
              ErrorReporter.report(
                e,
                stackTrace: stack,
                source: 'auth',
                action: 'link_existing_customer',
              );
            }
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
  }, (error, stack) {
    ErrorReporter.captureAsyncError(error, stack);
  });
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
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
