import 'package:ai_usage_monitor/src/data/burn_rate.dart';
import 'package:ai_usage_monitor/src/providers/types.dart';
import 'package:flutter_test/flutter_test.dart';

LimitWindow _window({
  double used = 0,
  double cap = 100,
  int resetAt = 0,
  bool exceeded = false,
}) => LimitWindow(
      id: 'test',
      label: 'Test pool',
      used: used,
      cap: cap,
      resetAt: resetAt,
      exceeded: exceeded,
    );

void main() {
  group('dailyPace', () {
    test('returns zero with no complete days of data', () {
      final now = DateTime(2026, 8, 21, 12);
      final pace = dailyPace(const [(day: '2026-08-21', costUsd: 10)], now: now);
      expect(pace.perDay, 0);
    });

    test('averages trailing complete days', () {
      final now = DateTime(2026, 8, 21, 23);
      final pace = dailyPace(
        const [
          (day: '2026-08-18', costUsd: 10),
          (day: '2026-08-19', costUsd: 14),
          (day: '2026-08-20', costUsd: 17),
        ],
        now: now,
      );
      // Mean of the three complete days; latest point is not "today"
      // relative to `now`, so no partial-day scaling applies.
      expect(pace.perDay, closeTo(13.667, 0.001));
    });

    test('scales today partial spend into the estimate', () {
      // It is 12:00 on the 21st; today already shows $6 spent.
      final now = DateTime(2026, 8, 21, 12);
      final pace = dailyPace(
        const [
          (day: '2026-08-19', costUsd: 10),
          (day: '2026-08-20', costUsd: 10),
          (day: '2026-08-21', costUsd: 6),
        ],
        now: now,
      );
      // Baseline = 10; today's rate = 6 / 0.5 = 12 (under the 3x cap) →
      // blended (10*2 + 12) / 3 = 10.667.
      expect(pace.perDay, closeTo(10.667, 0.001));
    });

    test('caps the today extrapolation at 3x the baseline', () {
      final now = DateTime(2026, 8, 21, 12);
      final pace = dailyPace(
        const [
          (day: '2026-08-19', costUsd: 1),
          (day: '2026-08-20', costUsd: 1),
          (day: '2026-08-21', costUsd: 30),
        ],
        now: now,
      );
      // Raw rate 60 capped to 3 → (1*2 + 3) / 3 = 1.667.
      expect(pace.perDay, closeTo(1.667, 0.001));
    });

    test('ignores today partial before the day is a quarter gone', () {
      final now = DateTime(2026, 8, 21, 3);
      final pace = dailyPace(
        const [
          (day: '2026-08-20', costUsd: 20),
          (day: '2026-08-21', costUsd: 999),
        ],
        now: now,
      );
      expect(pace.perDay, closeTo(20, 0.001));
    });
  });

  group('PoolOutlook.forWindow', () {
    test('flags runsOutEarly when pace empties pool before reset', () {
      final now = DateTime(2026, 8, 21, 12);
      final reset = now.add(const Duration(days: 5)).millisecondsSinceEpoch;
      final outlook = PoolOutlook.forWindow(
        _window(used: 50, cap: 60, resetAt: reset),
        10, // $10/day → empty in 1 day, reset in 5.
        now: now,
      );
      expect(outlook.daysToEmpty, closeTo(1, 0.01));
      expect(outlook.runsOutEarly, isTrue);
      expect(outlook.verdict(), contains('before reset'));
    });

    test('on pace when pool survives until reset', () {
      final now = DateTime(2026, 8, 21, 12);
      final reset = now.add(const Duration(days: 5)).millisecondsSinceEpoch;
      final outlook = PoolOutlook.forWindow(
        _window(used: 50, cap: 60, resetAt: reset),
        1,
        now: now,
      );
      expect(outlook.runsOutEarly, isFalse);
      expect(outlook.verdict(), 'on pace');
    });

    test('no pace data means neutral verdict', () {
      final outlook = PoolOutlook.forWindow(_window(used: 50, cap: 60), 0);
      expect(outlook.daysToEmpty, isNull);
      expect(outlook.verdict(), 'on pace');
    });

    test('exceeded window reports empty regardless of pace', () {
      final outlook = PoolOutlook.forWindow(_window(used: 70, cap: 60, exceeded: true), 5);
      expect(outlook.fraction, 1.0);
      expect(outlook.verdict(), 'empty');
    });
  });
}
