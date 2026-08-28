/// Burn-rate projections: how fast each pool is draining and whether it
/// survives until its reset.
library;

import '../providers/types.dart';

/// Trailing-window daily pace from a per-day spend series (each point is the
/// spend observed that day, not a cumulative total).
({double perDay, int windowDays}) dailyPace(
  List<({String day, double costUsd})> series, {
  int windowDays = 3,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final points =
      series.map((e) => (day: DateTime.parse(e.day), cost: e.costUsd)).toList()
        ..sort((a, b) => a.day.compareTo(b.day));

  // Baseline: mean of the most recent complete days (today excluded).
  final past = points
      .where((p) => p.day.isBefore(today))
      .map((p) => p.cost)
      .toList();
  if (past.isEmpty) return (perDay: 0, windowDays: windowDays);
  final recent = past.length > windowDays
      ? past.sublist(past.length - windowDays)
      : past;
  var perDay = recent.fold<double>(0, (s, c) => s + c) / recent.length;

  // Blend in today's partial spend, scaled to a full-day estimate once the
  // day is far enough along for the extrapolation to be meaningful.
  final last = points.last;
  if (last.day == today) {
    final fractionOfDay = (now.hour * 60 + now.minute) / 1440.0;
    if (fractionOfDay > 0.25 && fractionOfDay < 1) {
      final capped = (last.cost / fractionOfDay).clamp(0.0, perDay * 3);
      perDay = (perDay * recent.length + capped) / (recent.length + 1);
    }
  }
  return (perDay: perDay, windowDays: windowDays);
}

({double tokensPerDay, int windowDays}) dailyTokenPace(
  List<({String day, int inputTokens, int outputTokens})> series, {
  int windowDays = 3,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final points =
      series
          .map(
            (e) => (
              day: DateTime.parse(e.day),
              cost: (e.inputTokens + e.outputTokens).toDouble(),
            ),
          )
          .toList()
        ..sort((a, b) => a.day.compareTo(b.day));
  final past = points
      .where((p) => p.day.isBefore(today))
      .map((p) => p.cost)
      .toList();
  if (past.isEmpty) return (tokensPerDay: 0, windowDays: windowDays);
  final recent = past.length > windowDays
      ? past.sublist(past.length - windowDays)
      : past;
  var perDay = recent.fold<double>(0, (s, c) => s + c) / recent.length;
  final last = points.last;
  if (last.day == today) {
    final fractionOfDay = (now.hour * 60 + now.minute) / 1440.0;
    if (fractionOfDay > 0.25 && fractionOfDay < 1) {
      final capped = (last.cost / fractionOfDay).clamp(0.0, perDay * 3);
      perDay = (perDay * recent.length + capped) / (recent.length + 1);
    }
  }
  return (tokensPerDay: perDay, windowDays: windowDays);
}

List<({String day, double costPer1k})> costPer1kSeries(
  List<({String day, double costUsd, int inputTokens, int outputTokens})>
  joined,
) {
  return [
    for (final p in joined)
      (
        day: p.day,
        costPer1k: (p.inputTokens + p.outputTokens) > 0
            ? p.costUsd / ((p.inputTokens + p.outputTokens) / 1000)
            : 0.0,
      ),
  ];
}

/// Verdict for one budget pool at the current burn rate.
class PoolOutlook {
  final double used;
  final double cap;
  final double perDay;

  /// Days of usage left before the pool empties at [perDay]; null when
  /// unbounded (no cap or no measurable pace).
  final double? daysToEmpty;

  /// Days until the pool resets; null when unknown.
  final double? daysToReset;

  /// True when projected spend at reset exceeds the cap.
  final bool runsOutEarly;

  const PoolOutlook({
    required this.used,
    required this.cap,
    required this.perDay,
    required this.daysToEmpty,
    required this.daysToReset,
    required this.runsOutEarly,
  });

  factory PoolOutlook.forWindow(
    LimitWindow window,
    double perDay, {
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final remaining = window.cap - window.used;
    final daysToReset = window.resetAt > 0
        ? (window.resetAt - now.millisecondsSinceEpoch) / 86400000
        : null;
    final daysToEmpty = (window.cap > 0 && perDay > 0)
        ? remaining / perDay
        : null;
    final runsOutEarly =
        daysToEmpty != null &&
        daysToReset != null &&
        daysToReset > 0 &&
        daysToEmpty < daysToReset &&
        !window.exceeded;
    return PoolOutlook(
      used: window.used,
      cap: window.cap,
      perDay: perDay,
      daysToEmpty: daysToEmpty,
      daysToReset: daysToReset,
      runsOutEarly: runsOutEarly,
    );
  }

  double get fraction => cap > 0 ? (used / cap).clamp(0.0, 1.0) : 0.0;

  /// Dollars still in the pool.
  double get remaining {
    if (cap <= 0) return 0;
    final left = cap - used;
    return left < 0 ? 0 : left;
  }

  /// Daily spend that would land exactly on the cap at reset.
  double? get safePerDay {
    if (cap <= 0 || daysToReset == null || daysToReset! <= 0) return null;
    if (remaining <= 0) return 0;
    return remaining / daysToReset!;
  }

  /// Short human verdict, e.g. "on pace" / "runs out ~2d before reset".
  String verdict() {
    if (cap <= 0) return 'uncapped';
    if (fraction >= 1) return 'empty';
    if (daysToEmpty == null || perDay <= 0) return 'on pace';
    if (runsOutEarly) {
      final shortBy = daysToReset! - daysToEmpty!;
      if (shortBy < 1) return 'tight — out in ${_fmt(daysToEmpty!)}';
      return 'out ${_fmt(shortBy)} before reset';
    }
    return 'on pace';
  }

  static String _fmt(double days) {
    if (days < 1) return '${(days * 24).round()}h';
    if (days < 10) return '${days.toStringAsFixed(1)}d';
    return '${days.round()}d';
  }
}
