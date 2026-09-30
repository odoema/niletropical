import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nile_tropical/core/theme/app_theme.dart';

void main() {
  test('light theme builds and keeps the brand colour scheme', () {
    final theme = AppTheme.light;
    expect(theme.colorScheme.primary, NileColors.primary);
    expect(theme.colorScheme.onPrimary, NileColors.onPrimary);
    expect(theme.scaffoldBackgroundColor, NileColors.background);
  });

  test('typography uses Poppins with a system fallback', () {
    final style = NileTypography.bodyLarge;
    expect(style.fontFamily, contains('Poppins'));
    expect(style.fontFamilyFallback, isNotEmpty);
  });

  testWidgets('themed components render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Buy')),
              const Chip(label: Text('Shea')),
              Switch(value: true, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Buy'), findsOneWidget);
  });
}
