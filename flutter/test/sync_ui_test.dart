import 'package:ai_usage_monitor/src/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed sync chip exposes retry action', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncChip(
            lastAttemptAt: DateTime.now(),
            lastSuccessAt: DateTime.now().subtract(const Duration(hours: 1)),
            syncing: false,
            failed: true,
            onTap: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('SYNC FAILED'), findsOneWidget);
    expect(find.byTooltip('Retry sync'), findsOneWidget);

    await tester.tap(find.byTooltip('Retry sync'));
    expect(retried, isTrue);
  });
}
