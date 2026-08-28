import 'dart:convert';
import 'package:http/http.dart' as http;

import 'types.dart';

const _base = 'https://api.anthropic.com';
const _version = '2023-06-01';

/// Anthropic org spend: Admin API key (sk-ant-admin-…) required — regular
/// sk-ant-api keys get 403. No caps exist; the month is an uncapped "extra"
/// window.
class AnthropicProvider implements AiProvider {
  AnthropicProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'anthropic';
  @override
  String get name => 'Anthropic';
  @override
  String get howToGetToken =>
      'Paste an Anthropic Admin API key (starts with "sk-ant-admin-") from '
      'Claude Console → Settings → Admin API keys. Requires an organization — '
      'regular sk-ant-api keys cannot read org usage.';
  @override
  String get keyHint => 'sk-ant-admin-…';
  @override
  String get keyPattern => r'^sk-ant-admin';

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final res = await _client.get(
      Uri.parse('$_base$path'),
      headers: {
        'x-api-key': token,
        'anthropic-version': _version,
        'Accept': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      String message = res.body;
      try {
        final err = jsonDecode(res.body);
        if (err is Map<String, dynamic>) {
          message =
              (err['error'] as Map<String, dynamic>?)?['message'] as String? ??
              err['message'] as String? ??
              res.body;
        }
      } catch (_) {}
      if (res.statusCode == 403) {
        throw Exception('Anthropic usage needs an Admin key: $message');
      }
      throw Exception(
        'Anthropic API ${res.statusCode}: ${message.length > 200 ? message.substring(0, 200) : message}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String _monthStartIso() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month).toIso8601String();
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  String _reportQuery() {
    final start = Uri.encodeQueryComponent(_monthStartIso());
    final end = Uri.encodeQueryComponent(_nowIso());
    return 'starting_at=$start&ending_at=$end&bucket_width=1d';
  }

  static Iterable<Map<String, dynamic>> _buckets(Object? data) sync* {
    if (data is List) {
      for (final b in data) {
        if (b is Map<String, dynamic>) yield b;
      }
    } else if (data is Map<String, dynamic>) {
      yield data;
    }
  }

  static Iterable<Map<String, dynamic>> _results(Object? raw) sync* {
    if (raw is List) {
      for (final r in raw) {
        if (r is Map<String, dynamic>) yield r;
      }
    }
  }

  static double _costFromResult(Map<String, dynamic> result) {
    final amount = result['amount'];
    if (amount is Map<String, dynamic>) {
      final currency = (amount['currency'] as String? ?? 'usd').toLowerCase();
      if (currency == 'usd') return _n(amount['value']);
    }
    for (final key in ['cost_usd', 'cost', 'total_cost', 'amount_usd']) {
      final v = _n(result[key]);
      if (v > 0) return v;
    }
    return 0;
  }

  @override
  Future<ProviderIdentity> verify(String token) async {
    await _get('/v1/organizations/cost_report?${_reportQuery()}', token);
    return const ProviderIdentity(
      accountKey: 'anthropic:org',
      label: 'Anthropic',
      email: '',
    );
  }

  @override
  Future<ProviderUsage> fetchUsage(String token) async {
    final query = _reportQuery();
    final costBody = await _get('/v1/organizations/cost_report?$query', token);
    final usageBody = await _get(
      '/v1/organizations/usage_report/messages?$query',
      token,
    );

    var monthCost = 0.0;
    for (final bucket in _buckets(costBody['data'])) {
      for (final result in _results(bucket['results'])) {
        final value = _costFromResult(result);
        if (value > 0) monthCost += value;
      }
    }

    final tokensByModel = <String, (int, int, int, int)>{};
    var requests = 0, inputTokens = 0, outputTokens = 0;
    for (final bucket in _buckets(usageBody['data'])) {
      for (final result in _results(bucket['results'])) {
        final model = result['model'] as String? ?? 'unknown';
        final input = _n(result['input_tokens']).toInt();
        final output = _n(result['output_tokens']).toInt();
        final cacheRead = _n(result['cache_read_input_tokens']).toInt();
        final cacheWrite = _n(result['cache_creation_input_tokens']).toInt();
        requests += _n(result['num_model_requests']).toInt();
        inputTokens += input;
        outputTokens += output;
        final prev = tokensByModel[model] ?? (0, 0, 0, 0);
        tokensByModel[model] = (
          prev.$1 + input,
          prev.$2 + output,
          prev.$3 + cacheRead,
          prev.$4 + cacheWrite,
        );
      }
    }

    final models =
        tokensByModel.entries
            .map(
              (e) => ModelUsage(
                model: e.key,
                inputTokens: e.value.$1,
                outputTokens: e.value.$2,
                cacheReadTokens: e.value.$3,
                cacheWriteTokens: e.value.$4,
                costUsd: 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalTokens.compareTo(a.totalTokens));

    final windows = <LimitWindow>[
      if (monthCost > 0 || inputTokens > 0 || outputTokens > 0)
        LimitWindow(
          id: 'anthropic:month',
          label: 'This month',
          used: monthCost,
          cap: 0,
          kind: LimitKind.extra,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          requests: requests,
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

  static double _n(Object? v) =>
      v is num ? v.toDouble() : num.tryParse('$v')?.toDouble() ?? 0;
}
