import 'dart:convert';
import 'package:http/http.dart' as http;

import 'types.dart';

const _base = 'https://api2.cursor.sh';

/// Connect unary over plain HTTPS + JSON — verified working against api2.cursor.sh.
class CursorProvider implements AiProvider {
  @override
  String get id => 'cursor';
  @override
  String get name => 'Cursor';
  @override
  String get howToGetToken =>
      'Run `cursor-agent login` on your desktop (device OAuth prints a URL to approve), '
      'then paste the account token here. It lets this app read your usage only.';

  Future<Map<String, dynamic>> _rpc(String service, String method, Map<String, dynamic> body, String token) async {
    final res = await http.post(
      Uri.parse('$_base/$service/$method'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Connect-Protocol-Version': '1',
        'x-cursor-client-type': 'mobile',
        'x-cursor-client-version': 'mobile-1',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('Cursor API ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<ProviderIdentity> verify(String token) async {
    final me = await _rpc('aiserver.v1.DashboardService', 'GetMe', {}, token);
    final id = me['userId'] ?? me['authId'];
    if (id == null) throw Exception('Invalid Cursor token');
    final first = me['firstName'] as String? ?? '';
    final last = me['lastName'] as String? ?? '';
    return ProviderIdentity(
      accountKey: 'cursor:${me['userId'] ?? me['authId']}',
      label: '$first $last'.trim().isEmpty ? 'Cursor' : '$first $last'.trim(),
      email: me['email'] as String? ?? '',
    );
  }

  @override
  Future<ProviderUsage> fetchUsage(String token) async {
    final results = await Future.wait([
      _rpc('aiserver.v1.DashboardService', 'GetCurrentPeriodUsage', {}, token),
      _rpc('aiserver.v1.DashboardService', 'GetAggregatedUsageEvents', {}, token),
    ]);
    final period = results[0];
    final agg = results[1];

    final plan = period['planUsage'] as Map<String, dynamic>? ?? {};
    final spent = _num(plan['totalSpend']).toDouble();
    final included = _num(plan['includedSpend']).toDouble();

    // Token totals from per-model aggregations.
    final aggs = (agg['aggregations'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    var inputTokens = 0, outputTokens = 0;
    final models = <ModelUsage>[];
    for (final a in aggs) {
      final it = _num(a['inputTokens']).toInt();
      final ot = _num(a['outputTokens']).toInt();
      final cr = _num(a['cacheReadTokens']).toInt();
      final cw = _num(a['cacheWriteTokens']).toInt();
      final tc = _num(a['totalCents']).toDouble();
      inputTokens += it;
      outputTokens += ot;
      models.add(ModelUsage(
        model: a['modelIntent'] as String? ?? 'unknown',
        inputTokens: it,
        outputTokens: ot,
        cacheReadTokens: cr,
        cacheWriteTokens: cw,
        costUsd: tc / 100,
      ));
    }
    if (models.isEmpty) {
      // Fall back to response-level totals if aggregations are empty.
      inputTokens = _num(agg['totalInputTokens']).toInt();
      outputTokens = _num(agg['totalOutputTokens']).toInt();
    }

    final windows = <LimitWindow>[];
    final cycleEnd = _num(period['billingCycleEnd']).toInt();

    // The plan's own percentages are authoritative (same numbers Cursor's UI shows):
    // autoPercentUsed = % of included usage consumed by auto (default) models,
    // apiPercentUsed = % of included usage consumed by named/API models.
    final includedDollars = included / 100;
    final autoPct = (_num(plan['autoPercentUsed']) / 100).clamp(0.0, 1.0);
    final apiPct = (_num(plan['apiPercentUsed']) / 100).clamp(0.0, 1.0);
    final totalPct = (_num(plan['totalPercentUsed']) / 100).clamp(0.0, 1.0);

    if (includedDollars > 0) {
      if (autoPct > 0) {
        windows.add(LimitWindow(
          id: 'cursor:auto',
          label: 'Auto models (included)',
          used: includedDollars * autoPct,
          cap: includedDollars,
          resetAt: cycleEnd,
          exceeded: autoPct >= 1.0,
        ));
      }
      if (apiPct > 0) {
        windows.add(LimitWindow(
          id: 'cursor:api',
          label: 'API models (named)',
          used: includedDollars * apiPct,
          cap: includedDollars,
          resetAt: cycleEnd,
          exceeded: apiPct >= 1.0,
        ));
      }
      if (totalPct > 0 && totalPct != autoPct) {
        windows.add(LimitWindow(
          id: 'cursor:included',
          label: 'Included total usage',
          used: includedDollars * totalPct,
          cap: includedDollars,
          resetAt: cycleEnd,
          exceeded: totalPct >= 1.0,
        ));
      }
    }

    return ProviderUsage(
      totals: UsageTotals(
        requests: agg['totalRequests'] as int? ?? 0,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        costUsd: spent / 100,
      ),
      windows: windows,
      models: models,
    );
  }

  /// Protobuf int64/uint64 fields come through JSON as strings — coerce both.
  static num _num(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }
}
