import 'dart:convert';
import 'package:http/http.dart' as http;

import 'types.dart';

const _base = 'https://api.commandcode.ai';

class CommandCodeProvider implements AiProvider {
  CommandCodeProvider({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'commandcode';
  @override
  String get name => 'Command Code';
  @override
  String get howToGetToken =>
      'Paste your Command Code API key (starts with "user_"). '
      'Find it in ~/.commandcode/auth.json (field "apiKey") or run /login in Command Code.';

  Future<Map<String, dynamic>> _api(String path, String token) async {
    final res = await _client.get(
      Uri.parse('$_base$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'User-Agent': 'ai-usage-monitor/1',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Command Code API ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<ProviderIdentity> verify(String token) async {
    final w = await _api('/alpha/whoami', token);
    final user = w['user'] as Map<String, dynamic>?;
    if (w['success'] != true || user == null || user['id'] == null) {
      throw Exception('Invalid Command Code key');
    }
    return ProviderIdentity(
      accountKey: 'cc:${user['id']}',
      label: (user['userName'] ?? user['name'] ?? 'Command Code') as String,
      email: user['email'] as String? ?? '',
    );
  }

  @override
  Future<ProviderUsage> fetchUsage(String token) async {
    final credits = await _api('/alpha/billing/credits', token);
    Map<String, dynamic>? sub;
    try {
      final raw = await _api('/alpha/billing/subscriptions', token);
      final data = raw['data'];
      if (data is Map<String, dynamic>) sub = data;
    } catch (_) {
      sub = null;
    }

    final periodStart = sub?['currentPeriodStart'] as String?;
    final since =
        periodStart ??
        DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 40))
            .toIso8601String();
    final summary = await _api(
      '/alpha/usage/summary?since=${Uri.encodeQueryComponent(since)}',
      token,
    );

    final windows = <LimitWindow>[];
    final wl = credits['windowLimits'] as Map<String, dynamic>?;
    final fiveHour = wl?['fiveHour'] as Map<String, dynamic>?;
    if (fiveHour != null) {
      windows.add(
        LimitWindow(
          id: 'commandcode:5h',
          label: '5-hour burst',
          used: _n(fiveHour['used']),
          cap: _n(fiveHour['cap']),
          resetAt: _ms(fiveHour['resetAt']),
          exceeded: fiveHour['exceeded'] == true,
          kind: LimitKind.burst,
        ),
      );
    }
    final weekly = wl?['weekly'] as Map<String, dynamic>?;
    if (weekly != null && _n(weekly['cap']) > 0) {
      windows.add(
        LimitWindow(
          id: 'commandcode:weekly',
          label: 'This week',
          used: _n(weekly['used']),
          cap: _n(weekly['cap']),
          resetAt: _ms(weekly['resetAt']),
          exceeded: weekly['exceeded'] == true,
          kind: LimitKind.budget,
        ),
      );
    }

    // monthlyCredits is remaining, not a cap. Pair it with this billing period's spend.
    final remaining = _n(
      (credits['credits'] as Map<String, dynamic>?)?['monthlyCredits'],
    );
    final monthlyUsed = _n(summary['totalMonthlyCredits']);
    final usedThisPeriod = monthlyUsed > 0
        ? monthlyUsed
        : _n(summary['totalCost']);
    final periodEnd = _isoMs(sub?['currentPeriodEnd']);
    if (remaining > 0 || usedThisPeriod > 0) {
      windows.add(
        LimitWindow(
          id: 'commandcode:monthly',
          label: 'This month',
          used: usedThisPeriod,
          cap: usedThisPeriod + remaining,
          resetAt: periodEnd,
          exceeded: remaining <= 0 && usedThisPeriod > 0,
          kind: LimitKind.budget,
        ),
      );
    }

    return ProviderUsage(
      totals: UsageTotals(
        requests: (summary['totalCount'] as num?)?.toInt() ?? 0,
        inputTokens: (summary['totalTokensIn'] as num?)?.toInt() ?? 0,
        outputTokens: (summary['totalTokensOut'] as num?)?.toInt() ?? 0,
        costUsd: usedThisPeriod,
      ),
      windows: windows,
    );
  }

  static double _n(Object? v) => v is num ? v.toDouble() : 0;

  static int _ms(Object? v) {
    final n = v is num ? v.toInt() : 0;
    if (n <= 0) return 0;
    if (n < 100000000000) return n * 1000;
    return n;
  }

  static int _isoMs(Object? v) {
    if (v is! String || v.isEmpty) return 0;
    final parsed = DateTime.tryParse(v);
    return parsed?.millisecondsSinceEpoch ?? 0;
  }
}
