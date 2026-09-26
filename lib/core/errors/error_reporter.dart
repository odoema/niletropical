import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorReporter {
  ErrorReporter._();

  static String? currentRoute;

  static void captureFlutterError(FlutterErrorDetails details) {
    report(
      details.exception,
      stackTrace: details.stack ?? StackTrace.current,
      severity: 'error',
      source: 'flutter_framework',
      action: 'framework_error',
      context: {
        'library': details.library,
        'context': details.context?.toString(),
        'silent': details.silent,
      },
    );
  }

  static void captureAsyncError(Object error, StackTrace stackTrace) {
    report(
      error,
      stackTrace: stackTrace,
      severity: 'fatal',
      source: 'flutter_async',
      action: 'uncaught_async_error',
    );
  }

  static void report(
    Object error, {
    StackTrace? stackTrace,
    String severity = 'error',
    String source = 'flutter',
    String? action,
    String? route,
    Map<String, dynamic>? context,
  }) {
    unawaited(_persist(
      error,
      stackTrace: stackTrace,
      severity: severity,
      source: source,
      action: action,
      route: route,
      context: context,
    ));
  }

  static Future<void> _persist(
    Object error, {
    StackTrace? stackTrace,
    required String severity,
    required String source,
    String? action,
    String? route,
    Map<String, dynamic>? context,
  }) async {
    try {
      final technical = _redact(error.toString());
      final friendly = friendlyMessage(error);
      final code = _errorCode(error);
      final safeContext = _sanitizeMap(context ?? <String, dynamic>{});
      final fingerprint = _fingerprint(
        '$source|${code ?? error.runtimeType}|${action ?? ''}|$technical',
      );

      await Supabase.instance.client.rpc(
        'record_app_error',
        params: {
          'p_severity': severity,
          'p_source': source,
          'p_error_code': code,
          'p_message': friendly,
          'p_technical_message': technical,
          'p_stack_trace': stackTrace?.toString(),
          'p_route': route ?? currentRoute,
          'p_action': action,
          'p_fingerprint': fingerprint,
          'p_context': safeContext,
        },
      );
    } catch (loggingError) {
      if (kDebugMode) {
        debugPrint('[Nile ErrorReporter] Could not persist error: $loggingError');
      }
    }
  }

  static String friendlyMessage(Object error) {
    final text = error.toString();
    final code = _errorCode(error);

    if (code == 'PGRST204') {
      return 'We could not complete that change because some data is temporarily unavailable. Please refresh and try again.';
    }
    if (code == '42501') {
      return 'You do not have permission to perform this action.';
    }
    if (code == '23505') {
      return 'That record already exists. Please check the details and try again.';
    }
    if (code == '23503') {
      return 'This action cannot be completed because another record depends on it.';
    }
    if (code == '23514') {
      return 'Some information does not meet the required rules. Please check your entries.';
    }
    if (code == '22P02') {
      return 'Some information is invalid. Please check your entries and try again.';
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection reset') ||
        text.contains('Network is unreachable') ||
        text.contains('TimeoutException')) {
      return 'We are having trouble connecting right now. Please check your internet connection and try again.';
    }
    if (error is AuthException ||
        text.contains('AuthException') ||
        text.contains('JWT') ||
        text.contains('session')) {
      return 'Your session may have expired. Please sign in again and retry.';
    }
    if (error is PostgrestException) {
      return 'We could not complete that request. Please try again. If the problem continues, contact support.';
    }
    return 'Something went wrong while completing that request. Please try again. If the problem continues, contact support.';
  }

  static String? _errorCode(Object error) {
    if (error is PostgrestException) return error.code;
    final match = RegExp(r'\\b(PGRST\\d{3}|[0-9A-Z]{5})\\b').firstMatch(error.toString());
    return match?.group(1);
  }

  static String _redact(String value) {
    var result = value;
    result = result.replaceAll(
      RegExp(r'Bearer\\s+[A-Za-z0-9._-]+', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    result = result.replaceAll(
      RegExp(r'(password|token|secret|authorization|access_token|refresh_token)=([^,\\s}]+)', caseSensitive: false),
      r'$1=[REDACTED]',
    );
    return result.length > 4000 ? result.substring(0, 4000) : result;
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final output = <String, dynamic>{};
    const blocked = {
      'password',
      'passcode',
      'otp',
      'token',
      'access_token',
      'refresh_token',
      'secret',
      'authorization',
      'card_number',
      'cvv',
      'pin',
    };

    input.forEach((key, value) {
      final lower = key.toLowerCase();
      if (blocked.any(lower.contains)) {
        output[key] = '[REDACTED]';
      } else if (value is Map<String, dynamic>) {
        output[key] = _sanitizeMap(value);
      } else if (value is List) {
        output[key] = value.take(20).map((item) {
          if (item is Map<String, dynamic>) return _sanitizeMap(item);
          return item is String && item.length > 500 ? item.substring(0, 500) : item;
        }).toList();
      } else if (value is String && value.length > 500) {
        output[key] = value.substring(0, 500);
      } else {
        output[key] = value;
      }
    });

    return output;
  }

  static String _fingerprint(String input) {
    final value = input.hashCode.abs().toRadixString(16);
    return value.padLeft(8, '0');
  }
}

class NileNavigatorObserver extends NavigatorObserver {
  void _set(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      ErrorReporter.currentRoute = name;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
}
