import 'package:ai_usage_monitor/src/providers/types.dart';
import 'package:ai_usage_monitor/src/services/limit_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

LimitWindow _window({
  double used = 0,
  double cap = 100,
  bool exceeded = false,
  LimitKind kind = LimitKind.budget,
}) => LimitWindow(
  id: 'weekly',
  label: 'Weekly pool',
  used: used,
  cap: cap,
  resetAt: 1_700_000_000_000,
  exceeded: exceeded,
  kind: kind,
);

void main() {
  group('alertTiersFor', () {
    test('returns empty below 80%', () {
      expect(alertTiersFor(_window(used: 79)), isEmpty);
      expect(alertTiersFor(_window(used: 0)), isEmpty);
    });

    test('returns 80 at exactly 80%', () {
      expect(alertTiersFor(_window(used: 80)), [80]);
    });

    test('returns 80 between 80% and 90%', () {
      expect(alertTiersFor(_window(used: 85)), [80]);
      expect(alertTiersFor(_window(used: 89.9)), [80]);
    });

    test('returns 90 at exactly 90%', () {
      expect(alertTiersFor(_window(used: 90)), [90]);
    });

    test('returns 90 between 90% and 100%', () {
      expect(alertTiersFor(_window(used: 92)), [90]);
      expect(alertTiersFor(_window(used: 99)), [90]);
    });

    test('returns 100 at full usage', () {
      expect(alertTiersFor(_window(used: 100)), [100]);
    });

    test('returns 100 when exceeded even below cap fraction', () {
      expect(alertTiersFor(_window(used: 50, exceeded: true)), [100]);
    });

    test('returns 100 not 90 when exceeded at high usage', () {
      expect(alertTiersFor(_window(used: 95, exceeded: true)), [100]);
    });

    test('returns empty when cap is zero', () {
      expect(alertTiersFor(_window(used: 0, cap: 0)), isEmpty);
    });

    test('works for extra windows with a cap', () {
      expect(alertTiersFor(_window(used: 85, kind: LimitKind.extra)), [80]);
    });
  });
}
