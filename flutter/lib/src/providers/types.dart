/// Shared provider types — every platform implements [AiProvider].
library;

class ProviderIdentity {
  final String accountKey;
  final String label;
  final String email;
  const ProviderIdentity({
    required this.accountKey,
    required this.label,
    required this.email,
  });
}

class UsageTotals {
  final int requests;
  final int inputTokens;
  final int outputTokens;
  final double costUsd;
  const UsageTotals({
    this.requests = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.costUsd = 0,
  });
}

/// How a usage window should be read in the UI.
///
/// - [budget]: a real used/cap pool (weekly, monthly, included allowance)
/// - [share]: a slice of a parent budget, shown as a percentage
/// - [burst]: a short rolling rate-limit (idle when unused)
/// - [extra]: uncapped spend beyond the included pool
enum LimitKind { budget, share, burst, extra }

class LimitWindow {
  final String id;
  final String label;
  final double used;
  final double cap;
  final int resetAt; // ms epoch, 0 = none
  final bool exceeded;
  final LimitKind kind;
  const LimitWindow({
    required this.id,
    required this.label,
    required this.used,
    required this.cap,
    this.resetAt = 0,
    this.exceeded = false,
    this.kind = LimitKind.budget,
  });

  double get fraction => cap > 0 ? (used / cap).clamp(0.0, 1.0) : 0.0;

  bool get idle => kind == LimitKind.burst && used <= 0 && resetAt <= 0;

  bool get hot => exceeded || (cap > 0 && fraction >= 0.9);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'used': used,
    'cap': cap,
    'resetAt': resetAt,
    'exceeded': exceeded,
    'kind': kind.name,
  };

  factory LimitWindow.fromJson(Map<String, dynamic> j) => LimitWindow(
    id: j['id'] as String? ?? '',
    label: j['label'] as String? ?? '',
    used: (j['used'] as num?)?.toDouble() ?? 0,
    cap: (j['cap'] as num?)?.toDouble() ?? 0,
    resetAt: (j['resetAt'] as num?)?.toInt() ?? 0,
    exceeded: j['exceeded'] as bool? ?? false,
    kind: _kindFrom(j),
  );

  static LimitKind _kindFrom(Map<String, dynamic> j) {
    final named = j['kind'] as String?;
    if (named != null) {
      return LimitKind.values.firstWhere(
        (k) => k.name == named,
        orElse: () => LimitKind.budget,
      );
    }
    final id = j['id'] as String? ?? '';
    if (id.endsWith(':auto') || id.endsWith(':api')) return LimitKind.share;
    if (id.endsWith(':5h')) return LimitKind.burst;
    if (id.endsWith(':extra')) return LimitKind.extra;
    return LimitKind.budget;
  }
}

class ModelUsage {
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  final double costUsd;
  /// Cursor only: `auto` or `api`. Null for other providers.
  final String? bucket;
  const ModelUsage({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheWriteTokens,
    required this.costUsd,
    this.bucket,
  });

  int get totalTokens => inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens;

  Map<String, dynamic> toJson() => {
    'model': model,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'cacheReadTokens': cacheReadTokens,
    'cacheWriteTokens': cacheWriteTokens,
    'costUsd': costUsd,
    if (bucket != null) 'bucket': bucket,
  };

  factory ModelUsage.fromJson(Map<String, dynamic> j) => ModelUsage(
    model: j['model'] as String? ?? '',
    inputTokens: (j['inputTokens'] as num?)?.toInt() ?? 0,
    outputTokens: (j['outputTokens'] as num?)?.toInt() ?? 0,
    cacheReadTokens: (j['cacheReadTokens'] as num?)?.toInt() ?? 0,
    cacheWriteTokens: (j['cacheWriteTokens'] as num?)?.toInt() ?? 0,
    costUsd: (j['costUsd'] as num?)?.toDouble() ?? 0,
    bucket: j['bucket'] as String?,
  );
}

class ProviderUsage {
  final UsageTotals totals;
  final List<LimitWindow> windows;
  final List<ModelUsage> models;
  const ProviderUsage({
    required this.totals,
    this.windows = const [],
    this.models = const [],
  });
}

abstract class AiProvider {
  String get id;
  String get name;
  String get howToGetToken;
  Future<ProviderIdentity> verify(String token);
  Future<ProviderUsage> fetchUsage(String token);
}
