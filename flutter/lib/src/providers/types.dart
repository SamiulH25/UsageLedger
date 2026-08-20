/// Shared provider types — every platform implements [AiProvider].
library;

class ProviderIdentity {
  final String accountKey;
  final String label;
  final String email;
  const ProviderIdentity({required this.accountKey, required this.label, required this.email});
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

class LimitWindow {
  final String id;
  final String label;
  final double used;
  final double cap;
  final int resetAt; // ms epoch, 0 = none
  final bool exceeded;
  const LimitWindow({
    required this.id,
    required this.label,
    required this.used,
    required this.cap,
    this.resetAt = 0,
    this.exceeded = false,
  });

  double get fraction => cap > 0 ? (used / cap).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'used': used,
        'cap': cap,
        'resetAt': resetAt,
        'exceeded': exceeded,
      };

  factory LimitWindow.fromJson(Map<String, dynamic> j) => LimitWindow(
        id: j['id'] as String? ?? '',
        label: j['label'] as String? ?? '',
        used: (j['used'] as num?)?.toDouble() ?? 0,
        cap: (j['cap'] as num?)?.toDouble() ?? 0,
        resetAt: (j['resetAt'] as num?)?.toInt() ?? 0,
        exceeded: j['exceeded'] as bool? ?? false,
      );
}

class ModelUsage {
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  final double costUsd;
  const ModelUsage({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheWriteTokens,
    required this.costUsd,
  });

  Map<String, dynamic> toJson() => {
        'model': model,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cacheReadTokens': cacheReadTokens,
        'cacheWriteTokens': cacheWriteTokens,
        'costUsd': costUsd,
      };

  factory ModelUsage.fromJson(Map<String, dynamic> j) => ModelUsage(
        model: j['model'] as String? ?? '',
        inputTokens: (j['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (j['outputTokens'] as num?)?.toInt() ?? 0,
        cacheReadTokens: (j['cacheReadTokens'] as num?)?.toInt() ?? 0,
        cacheWriteTokens: (j['cacheWriteTokens'] as num?)?.toInt() ?? 0,
        costUsd: (j['costUsd'] as num?)?.toDouble() ?? 0,
      );
}

class ProviderUsage {
  final UsageTotals totals;
  final List<LimitWindow> windows;
  final List<ModelUsage> models;
  const ProviderUsage({required this.totals, this.windows = const [], this.models = const []});
}

abstract class AiProvider {
  String get id;
  String get name;
  String get howToGetToken;
  Future<ProviderIdentity> verify(String token);
  Future<ProviderUsage> fetchUsage(String token);
}
