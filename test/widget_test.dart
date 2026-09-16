import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('material smoke', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Nile'))),
    );
    expect(find.text('Nile'), findsOneWidget);
  });
}
