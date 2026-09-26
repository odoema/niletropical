import 'package:flutter_test/flutter_test.dart';
import 'package:nile_tropical/core/errors/error_reporter.dart';

void main() {
  group('ErrorReporter.friendlyMessage', () {
    test('hides schema-cache details', () {
      final message = ErrorReporter.friendlyMessage(
        'PostgrestException(message: Could not find the reason column, code: PGRST204)',
      );
      expect(message, contains('data is temporarily unavailable'));
      expect(message, isNot(contains('PGRST204')));
    });

    test('handles permission errors professionally', () {
      final message = ErrorReporter.friendlyMessage(
        'PostgrestException(message: permission denied, code: 42501)',
      );
      expect(message, 'You do not have permission to perform this action.');
    });

    test('handles duplicate records', () {
      final message = ErrorReporter.friendlyMessage(
        'PostgrestException(message: duplicate key, code: 23505)',
      );
      expect(message, contains('already exists'));
    });

    test('handles network failures', () {
      final message = ErrorReporter.friendlyMessage(
        'SocketException: Failed host lookup',
      );
      expect(message, contains('trouble connecting'));
    });

    test('uses a safe generic fallback', () {
      final message = ErrorReporter.friendlyMessage(
        Exception('internal database details'),
      );
      expect(message, contains('Something went wrong'));
      expect(message, isNot(contains('internal database details')));
    });
  });
}
