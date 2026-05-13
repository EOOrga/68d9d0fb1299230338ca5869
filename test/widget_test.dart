import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:biehler_jean/main.dart';

void main() {
  testWidgets('creates and opens an operations request', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp(screenshotMode: false));
    await tester.pumpAndSettle();

    expect(find.text('Business operations board'), findsOneWidget);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-request-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('title-field')),
      'Printer toner order',
    );
    await tester.enterText(find.byKey(const Key('owner-field')), 'Office desk');
    await tester.enterText(find.byKey(const Key('value-field')), 'USD 180');
    await tester.enterText(
      find.byKey(const Key('notes-field')),
      'Keep two boxes in reserve.',
    );
    await tester.tap(find.byKey(const Key('save-request-button')));
    await tester.pumpAndSettle();

    expect(find.text('Printer toner order'), findsOneWidget);

    await tester.tap(find.text('Printer toner order'));
    await tester.pumpAndSettle();

    expect(find.text('Request detail'), findsOneWidget);
    expect(find.text('USD 180'), findsOneWidget);
  });

  testWidgets('screenshot mode loads sample records without persistence', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp(screenshotMode: true));
    await tester.pumpAndSettle();

    expect(find.text('Business operations board'), findsOneWidget);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    expect(find.text('May payroll variance report'), findsOneWidget);
  });
}
