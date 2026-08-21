import 'dart:convert';
import 'package:http/http.dart' as http;

import 'types.dart';

const _base = 'https://api.openai.com/v1';

/// OpenAI organization spend: admin key (sk-admin-…) required — project keys
/// get 403. No caps exist; the month is an uncapped "extra" window.
class OpenAiProvider implements AiProvider {
  OpenAiProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'openai';
  @override
  String get name => 'OpenAI';
  @override
  String get howToGetToken =>
      'Paste an OpenAI Admin key (starts with "sk-admin-") from '
      'platform.openai.com/settings/organization/admin-keys. Project keys '
      '(sk-proj-…) cannot read usage.';
  @override
  String get keyHint => 'sk-admin-…';
  @override
  String get keyPattern => r'^sk-admin-';

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final res = await _client.get(
      Uri.parse('$_base$path'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (res.statusCode != 200) {
      String message = res.body;
      try {
        message =
            (jsonDecode(res.body) as Map<String, dynamic>)['error']['message']
                as String? ??
            res.body;
      } catch (_) {}
      if (res.statusCode == 403) {
        throw Exception('OpenAI usage needs an Admin key: $message');
      }
      throw Exception(
        'OpenAI API ${res.statusCode}: ${message.length > 200 ? message.substring(0, 200) : message}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Paginates a bucketed page endpoint, following next_page up to [maxPages].
  Future<List<Map<String, dynamic>>> _pageAll(
    String path,
    Map<String, String> query,
    String token, {
    int maxPages = 6,
  }) async {
    final buckets = <Map<String, dynamic>>[];
    var page = '';
    for (var i = 0; i < maxPages; i++) {
      final qs = [
        ...query.entries.map((e) => '${e.key}=${e.value}'),
        if (page.isNotEmpty) 'page=$page',
      ].join('&');
      final body = await _get('$path?$qs', token);
      for (final b in (body['data'] as List? ?? const [])) {
        buckets.add(b as Map<String, dynamic>);
      }
      if (body['has_more'] != true) break;
      page = body['next_page'] as String? ?? '';
      if (page.isEmpty) break;
    }
    return buckets;
  }

  static int _monthStartUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month).millisecondsSinceEpoch ~/ 1000;
  }

  @override
  Future<ProviderIdentity> verify(String token) async {
    // Cheapest admin endpoint probe: one tiny costs bucket.
    await _get(
      '/organization/costs?start_time=${_monthStartUtc()}&limit=1',
      token,
    );
    return const ProviderIdentity(
      accountKey: 'openai:org',
      label: 'OpenAI',
      email: '',
    );
  }

  @override
  Future<ProviderUsage> fetchUsage(String token) async {
    final start = _monthStartUtc().toString();
    final window = Uri.encodeQueryComponent('["line_item"]');
    final byModel = Uri.encodeQueryComponent('["model"]');

    // Costs per pricing SKU (line_item ≈ model/pricing tier), daily buckets.
    final costBuckets = await _pageAll('/organization/costs', {
      'start_time': start,
      'bucket_width': '1d',
      'limit': '31',
      'group_by': window,
    }, token);
    final costByItem = <String, double>{};
    var monthCost = 0.0;
    for (final bucket in costBuckets) {
      for (final r in (bucket['results'] as List? ?? const [])) {
        final result = r as Map<String, dynamic>;
        final amount = result['amount'] as Map<String, dynamic>? ?? const {};
        final value = _n(amount['value']);
        if (value == 0) continue;
        final item = result['line_item'] as String? ?? 'other';
        costByItem[item] = (costByItem[item] ?? 0) + value;
        monthCost += value;
      }
    }

    // Token usage per model (completions + embeddings).
    final tokensByModel = <String, (int, int, int)>{};
    var requests = 0, inputTokens = 0, outputTokens = 0;

    void mergeUsageBuckets(List<Map<String, dynamic>> buckets) {
      for (final bucket in buckets) {
        for (final r in (bucket['results'] as List? ?? const [])) {
          final result = r as Map<String, dynamic>;
          final model = result['model'] as String? ?? 'unknown';
          final input = _n(result['input_tokens']).toInt();
          final output = _n(result['output_tokens']).toInt();
          final reqs = _n(result['num_model_requests']).toInt();
          requests += reqs;
          inputTokens += input;
          outputTokens += output;
          final prev = tokensByModel[model] ?? (0, 0, 0);
          tokensByModel[model] = (
            prev.$1 + input,
            prev.$2 + output,
            prev.$3 + reqs,
          );
        }
      }
    }

    mergeUsageBuckets(
      await _pageAll('/organization/usage/completions', {
        'start_time': start,
        'bucket_width': '1d',
        'limit': '31',
        'group_by': byModel,
      }, token),
    );
    try {
      mergeUsageBuckets(
        await _pageAll('/organization/usage/embeddings', {
          'start_time': start,
          'bucket_width': '1d',
          'limit': '31',
          'group_by': byModel,
        }, token),
      );
    } on Exception catch (e) {
      if (!e.toString().contains('404')) rethrow;
    }

    // Attach costs to models by fuzzy line_item match; leftover SKUs stand alone.
    final matchedItems = <String>{};
    final models = <ModelUsage>[];
    for (final entry in tokensByModel.entries) {
      final match = _matchCostItems(costByItem, entry.key);
      matchedItems.addAll(match.$2);
      models.add(
        ModelUsage(
          model: entry.key,
          inputTokens: entry.value.$1,
          outputTokens: entry.value.$2,
          cacheReadTokens: 0,
          cacheWriteTokens: 0,
          costUsd: match.$1,
        ),
      );
    }
    for (final entry in costByItem.entries) {
      if (matchedItems.contains(entry.key)) continue;
      models.add(
        ModelUsage(
          model: entry.key,
          inputTokens: 0,
          outputTokens: 0,
          cacheReadTokens: 0,
          cacheWriteTokens: 0,
          costUsd: entry.value,
        ),
      );
    }
    models.sort((a, b) => b.costUsd.compareTo(a.costUsd));

    final windows = <LimitWindow>[
      if (monthCost > 0)
        LimitWindow(
          id: 'openai:month',
          label: 'This month',
          used: monthCost,
          cap: 0,
          kind: LimitKind.extra,
        ),
    ];

    return ProviderUsage(
      totals: UsageTotals(
        requests: requests,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        costUsd: monthCost,
      ),
      windows: windows,
      models: models,
    );
  }

  /// line_item names don't equal model slugs ("GPT-4o" vs "gpt-4o…") —
  /// normalize and substring-match, else 0.
  static (double, Set<String>) _matchCostItems(
    Map<String, double> costs,
    String model,
  ) {
    var best = 0.0;
    final matched = <String>{};
    final m = model.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    for (final entry in costs.entries) {
      final item = entry.key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
      if (item.contains(m) || m.contains(item)) {
        best += entry.value;
        matched.add(entry.key);
      }
    }
    return (best, matched);
  }

  static double _n(Object? v) =>
      v is num ? v.toDouble() : num.tryParse('$v')?.toDouble() ?? 0;
}
