import 'dart:convert';
import 'package:http/http.dart' as http;

import 'types.dart';

const _base = 'https://api.deepseek.com';

/// DeepSeek: prepaid balance only — no spend history endpoint.
class DeepSeekProvider implements AiProvider {
  DeepSeekProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'deepseek';
  @override
  String get name => 'DeepSeek';
  @override
  String get howToGetToken =>
      'Paste your DeepSeek API key from platform.deepseek.com. '
      'Only account balance is available — there is no spend history API.';
  @override
  String get keyHint => 'sk-…';
  @override
  String get keyPattern => r'^sk-';

  Future<Map<String, dynamic>> _get(String token) async {
    final res = await _client.get(
      Uri.parse('$_base/user/balance'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'DeepSeek API ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}',
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

  static Map<String, dynamic>? _pickBalance(List<dynamic> infos) {
    for (final raw in infos) {
      if (raw is Map<String, dynamic> &&
          (raw['currency'] as String? ?? '').toUpperCase() == 'USD') {
        return raw;
      }
    }
    if (infos.isNotEmpty && infos.first is Map<String, dynamic>) {
      return infos.first as Map<String, dynamic>;
    }
    return null;
  }

  @override
  Future<ProviderIdentity> verify(String token) async {
    await _get(token);
    return ProviderIdentity(
      accountKey: 'deepseek:${_tokenHash(token)}',
      label: 'DeepSeek',
      email: '',
    );
  }

  @override
  Future<ProviderUsage> fetchUsage(String token) async {
    final body = await _get(token);
    final info = _pickBalance(body['balance_infos'] as List? ?? const []);

    final total = _n(info?['total_balance']);
    final granted = _n(info?['granted_balance']);
    final topped = _n(info?['topped_up_balance']);
    final purchased = granted + topped;

    final double cap;
    final double used;
    if (purchased > 0) {
      cap = total > purchased ? total : purchased;
      used = (cap - total).clamp(0, double.infinity);
    } else {
      cap = total;
      used = 0;
    }

    final windows = <LimitWindow>[
      if (cap > 0 || total > 0)
        LimitWindow(
          id: 'deepseek:balance',
          label: 'Credits',
          used: used,
          cap: cap,
          kind: LimitKind.budget,
        ),
    ];

    return ProviderUsage(
      totals: UsageTotals(costUsd: used),
      windows: windows,
    );
  }

  static double _n(Object? v) =>
      v is num ? v.toDouble() : num.tryParse('$v')?.toDouble() ?? 0;
}
