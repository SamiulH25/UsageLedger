import 'package:ai_usage_monitor/src/data/burn_rate.dart';
import 'package:ai_usage_monitor/src/providers/types.dart';
import 'package:ai_usage_monitor/src/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 8, 21, 12);

RunwayEntry _entry({
  required double used,
  required double cap,
  Duration? resetIn,
  required double perDay,
  bool exceeded = false,
}) {
  final window = LimitWindow(
    id: 'test:pool',
    label: 'Monthly pool',
    used: used,
    cap: cap,
    resetAt: resetIn == null
        ? 0
        : _now.add(resetIn).millisecondsSinceEpoch,
    exceeded: exceeded,
  );
  return RunwayEntry(
    accountLabel: 'Test account',
    window: window,
    outlook: PoolOutlook.forWindow(window, perDay, now: _now),
  );
}

void main() {
  group('RunwayEntry', () {
    test('a pool that outlasts its window fills the whole lane', () {
      final entry = _entry(
        used: 50,
        cap: 100,
        resetIn: const Duration(days: 2),
        perDay: 10,
      );

      expect(entry.survivedFraction, 1);
      expect(entry.dryEarlyBy, isNull);
      expect(entry.timeToWall, isNull);
    });

    test('a pool that runs dry early leaves a proportional dead zone', () {
      final entry = _entry(
        used: 50,
        cap: 100,
        resetIn: const Duration(days: 10),
        perDay: 10,
      );

      // 50 left at 10/day lasts 5 of the 10 remaining days.
      expect(entry.survivedFraction, closeTo(0.5, 1e-9));
      expect(entry.dryEarlyBy!.inDays, 5);
      expect(entry.timeToWall!.inDays, 5);
    });

    test('an empty pool has no runway at all', () {
      final entry = _entry(
        used: 100,
        cap: 100,
        resetIn: const Duration(days: 3),
        perDay: 10,
      );

      expect(entry.survivedFraction, 0);
      expect(entry.timeToWall, Duration.zero);
    });

    test('an over-cap pool is treated as empty even below the cap', () {
      final entry = _entry(
        used: 20,
        cap: 100,
        resetIn: const Duration(days: 3),
        perDay: 10,
        exceeded: true,
      );

      expect(entry.survivedFraction, 0);
      expect(entry.timeToWall, Duration.zero);
    });

    test('no reset time means the pool cannot be projected', () {
      final entry = _entry(used: 50, cap: 100, perDay: 10);

      expect(entry.pending, isTrue);
      expect(entry.survivedFraction, 1);
    });

    test('no measurable pace means no wall is predicted', () {
      final entry = _entry(
        used: 50,
        cap: 100,
        resetIn: const Duration(days: 10),
        perDay: 0,
      );

      expect(entry.survivedFraction, 1);
      expect(entry.timeToWall, isNull);
    });
  });

  group('RunwayLane', () {
    Future<void> pump(WidgetTester tester, RunwayEntry entry) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RunwayLane(entry: entry)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('says so when a pool lasts to its reset', (tester) async {
      await pump(
        tester,
        _entry(
          used: 50,
          cap: 100,
          resetIn: const Duration(days: 2),
          perDay: 10,
        ),
      );

      expect(find.text('lasts to reset'), findsOneWidget);
    });

    testWidgets('names how early a pool runs dry', (tester) async {
      await pump(
        tester,
        _entry(
          used: 50,
          cap: 100,
          resetIn: const Duration(days: 10),
          perDay: 10,
        ),
      );

      expect(find.text('dry 5d early'), findsOneWidget);
    });

    testWidgets('an empty pool reports when it comes back', (tester) async {
      await pump(
        tester,
        _entry(
          used: 100,
          cap: 100,
          resetIn: const Duration(days: 3),
          perDay: 10,
        ),
      );

      expect(find.textContaining('empty'), findsOneWidget);
    });

    testWidgets('says pace is unknown rather than guessing', (tester) async {
      await pump(
        tester,
        _entry(
          used: 50,
          cap: 100,
          resetIn: const Duration(days: 10),
          perDay: 0,
        ),
      );

      expect(find.text('pace unknown'), findsOneWidget);
    });
  });
}
