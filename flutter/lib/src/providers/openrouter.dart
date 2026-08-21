import 'dart:convert';
import 'package:http/http.dart' as http;

import 'types.dart';

const _base = 'https://openrouter.ai/api/v1';

/// OpenRouter: prepaid credits, no reset windows. /credits + /activity need a
/// Management key; /key works with regular keys — degrade gracefully.
class OpenRouterProvider implements AiProvider {
  OpenRouterProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'openrouter';
  @override
  String get name => 'OpenRouter';
  @override
  String get howToGetToken =>
      'Paste an OpenRouter key. A Management key (openrouter.ai/settings/'
      'management-keys) unlocks balance + per-model history; a regular key '
      '(sk-or-v1-…) shows that key\'s quota and usage only.';
  @override
  String get keyHint => 'sk-or-…';
  // Management keys have no documented prefix — advisory only.
  @override
  String get keyPattern => r'^sk-or-';

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final res = await _client.get(
      Uri.parse('$_base$path'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'OpenRouter API ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// FNV-1a — stable across runs (String.hashCode is not guaranteed to be).
  static String _tokenHash(String token) {
    var hash = 0x811c9dc5;
    for (final unit in token.trim().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(36);
  }

  @override
  Future<ProviderIdentity> verify(String token) async {
    final body = await _get('/key', token);
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return ProviderIdentity(
      accountKey: 'openrouter:${_tokenHash(token)}',
      label: (data['label'] as String?)?.isNotEmpty == true
          ? data['label'] as String
          : 'OpenRouter',
      email: '',
    );
  }

  @override
  Future<ProviderUsage> fetchUsage(String token) async {
    final windows = <LimitWindow>[];
    final models = <ModelUsage>[];
    double totalUsage = 0;
    int requests = 0, inputTokens = 0, outputTokens = 0;

    // Prepaid balance — management keys only; regular keys get 403.
    double? totalCredits;
    try {
      final credits = await _get('/credits', token);
      final data = credits['data'] as Map<String, dynamic>? ?? const {};
      totalCredits = _n(data['total_credits']);
      totalUsage = _n(data['total_usage']);
    } on Exception catch (e) {
      if (!e.toString().contains('403')) rethrow;
    }

    // Key-level quota (any key type).
    final keyBody = await _get('/key', token);
    final key = keyBody['data'] as Map<String, dynamic>? ?? const {};
    if (totalUsage == 0) totalUsage = _n(key['usage']);
    final limit = _n(key['limit']);
    if (limit > 0) {
      windows.add(
        LimitWindow(
          id: 'openrouter:key',
          label: 'Key quota',
          used: _n(key['usage']),
          cap: limit,
          kind: LimitKind.budget,
        ),
      );
    }
    final credits = totalCredits;
    if (credits != null && credits > 0) {
      windows.add(
        LimitWindow(
          id: 'openrouter:credits',
          label: 'Credits',
          used: totalUsage,
          cap: credits,
          kind: LimitKind.budget,
        ),
      );
    }

    // Per-model history: last 30 UTC days, one row per (date, model, endpoint).
    final activity = await _get('/activity', token);
    final rows = activity['data'] as List? ?? const [];
    final byModel = <String, ModelUsage>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final model = row['model'] as String? ?? 'unknown';
      final existing = byModel[model];
      final usage = _n(row['usage']);
      final prompt = _n(row['prompt_tokens']).toInt();
      final completion =
          _n(row['completion_tokens']).toInt() +
          _n(row['reasoning_tokens']).toInt();
      final reqs = _n(row['requests']).toInt();
      requests += reqs;
      inputTokens += prompt;
      outputTokens += completion;
      byModel[model] = ModelUsage(
        model: model,
        inputTokens: (existing?.inputTokens ?? 0) + prompt,
        outputTokens: (existing?.outputTokens ?? 0) + completion,
        cacheReadTokens: 0,
        cacheWriteTokens: 0,
        costUsd: (existing?.costUsd ?? 0) + usage,
      );
    }
    models
      ..addAll(byModel.values)
      ..sort((a, b) => b.costUsd.compareTo(a.costUsd));

    return ProviderUsage(
      totals: UsageTotals(
        requests: requests,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        costUsd: totalUsage,
      ),
      windows: windows,
      models: models,
    );
  }

  static double _n(Object? v) =>
      v is num ? v.toDouble() : num.tryParse('$v')?.toDouble() ?? 0;
}
