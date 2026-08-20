import 'dart:convert';
import 'package:http/http.dart' as http;

import 'types.dart';

const _base = 'https://api.commandcode.ai';

class CommandCodeProvider implements AiProvider {
  @override
  String get id => 'commandcode';
  @override
  String get name => 'Command Code';
  @override
  String get howToGetToken =>
      'Paste your Command Code API key (starts with "user_"). '
      'Find it in ~/.commandcode/auth.json (field "apiKey") or run /login in Command Code.';

  Future<Map<String, dynamic>> _api(String path, String token) async {
    final res = await http.get(
      Uri.parse('$_base$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'User-Agent': 'ai-usage-monitor/1',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Command Code API ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
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
    final since = DateTime.now().subtract(const Duration(days: 40)).toUtc().toIso8601String();
    final results = await Future.wait([
      _api('/alpha/usage/summary?since=${Uri.encodeQueryComponent(since)}', token),
      _api('/alpha/billing/credits', token),
    ]);
    final summary = results[0];
    final credits = results[1];

    final windows = <LimitWindow>[];
    final wl = credits['windowLimits'] as Map<String, dynamic>?;
    final fiveHour = wl?['fiveHour'] as Map<String, dynamic>?;
    if (fiveHour != null) {
      windows.add(LimitWindow(
        id: 'commandcode:5h',
        label: '5-hour window',
        used: (fiveHour['used'] as num).toDouble(),
        cap: (fiveHour['cap'] as num).toDouble(),
        resetAt: (fiveHour['resetAt'] as num?)?.toInt() ?? 0,
        exceeded: fiveHour['exceeded'] == true,
      ));
    }
    final weekly = wl?['weekly'] as Map<String, dynamic>?;
    if (weekly != null) {
      windows.add(LimitWindow(
        id: 'commandcode:weekly',
        label: 'Weekly',
        used: (weekly['used'] as num).toDouble(),
        cap: (weekly['cap'] as num).toDouble(),
        resetAt: (weekly['resetAt'] as num?)?.toInt() ?? 0,
        exceeded: weekly['exceeded'] == true,
      ));
    }
    final monthly = (credits['credits'] as Map<String, dynamic>?)?['monthlyCredits'];
    final totalCost = (summary['totalCost'] as num?)?.toDouble() ?? 0;
    if (monthly is num && monthly > 0) {
      windows.add(LimitWindow(
        id: 'commandcode:monthly',
        label: 'Monthly credits',
        used: totalCost,
        cap: monthly.toDouble(),
        exceeded: totalCost > monthly.toDouble(),
      ));
    }

    return ProviderUsage(
      totals: UsageTotals(
        requests: (summary['totalCount'] as num?)?.toInt() ?? 0,
        inputTokens: (summary['totalTokensIn'] as num?)?.toInt() ?? 0,
        outputTokens: (summary['totalTokensOut'] as num?)?.toInt() ?? 0,
        costUsd: totalCost,
      ),
      windows: windows,
    );
  }
}
