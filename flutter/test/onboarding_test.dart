import 'package:ai_usage_monitor/src/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Add an account completes onboarding and requests account flow', (
    tester,
  ) async {
    bool? openAddAccount;
    var persisted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          persistOnboarding: () async => persisted = true,
          onDone: (open) async => openAddAccount = open,
        ),
      ),
    );

    await tester.tap(find.text('ADD AN ACCOUNT'));
    await tester.pumpAndSettle();

    expect(persisted, isTrue);
    expect(openAddAccount, isTrue);
  });

  testWidgets('Not now completes onboarding without opening account flow', (
    tester,
  ) async {
    bool? openAddAccount;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          persistOnboarding: () async {},
          onDone: (open) async => openAddAccount = open,
        ),
      ),
    );

    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();

    expect(openAddAccount, isFalse);
  });
}
