import 'package:ai_usage_monitor/src/providers/registry.dart';
import 'package:ai_usage_monitor/src/screens/add_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add-account sheet lists every registered provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AddAccountScreen())),
    );
    await tester.pumpAndSettle();

    expect(providers, hasLength(4));
    for (final p in providers) {
      expect(find.text(p.name), findsOneWidget, reason: '${p.id} missing');
    }
    // Selecting a provider swaps the key placeholder.
    await tester.tap(find.text('OpenRouter'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Paste API key'), findsOneWidget);
  });

  testWidgets('mismatched keys show an advisory, not a blocker', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AddAccountScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Command Code'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Paste API key'),
      'definitely-not-a-key',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("doesn't look like a typical"), findsOneWidget);
    // The submit button stays enabled.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify & add account'),
    );
    expect(button.onPressed, isNotNull);
  });
}
