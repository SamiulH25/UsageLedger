import 'dart:convert';
import 'package:http/http.dart' as http;

import 'types.dart';

const _base = 'https://api2.cursor.sh';
const _refreshBufferMs = 5 * 60 * 1000;

class _CachedAccessToken {
  final String token;
  final int expiresAtMs;

  const _CachedAccessToken({required this.token, required this.expiresAtMs});

  bool get valid =>
      DateTime.now().millisecondsSinceEpoch < expiresAtMs - _refreshBufferMs;
}

/// Connect unary over plain HTTPS + JSON — verified working against api2.cursor.sh.
class CursorProvider implements AiProvider {
  static final _accessTokenCache = <String, _CachedAccessToken>{};

  @override
  String get id => 'cursor';
  @override
  String get name => 'Cursor';
  @override
  String get howToGetToken =>
      'Create a User API key at cursor.com/dashboard → Integrations → User API Keys '
      '(starts with "crsr_"). UsageLedger stores the key on-device and exchanges it for '
      'short-lived access tokens when syncing.';

  static bool isApiKey(String token) => token.trim().startsWith('crsr_');

  Future<Map<String, dynamic>> _rpc(
    String service,
    String method,
    Map<String, dynamic> body,
    String credential, {
    bool retried = false,
  }) async {
    final accessToken = await _resolveAccessToken(credential);
    final res = await http.post(
      Uri.parse('$_base/$service/$method'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Connect-Protocol-Version': '1',
        'x-cursor-client-type': 'mobile',
        'x-cursor-client-version': 'mobile-1',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode == 401 && isApiKey(credential) && !retried) {
      _accessTokenCache.remove(credential.trim());
      return _rpc(service, method, body, credential, retried: true);
    }
    if (res.statusCode != 200) {
      throw Exception(
        'Cursor API ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String> _resolveAccessToken(
    String credential, {
    bool forceRefresh = false,
  }) async {
    final trimmed = credential.trim();
    if (!isApiKey(trimmed)) return trimmed;

    if (!forceRefresh) {
      final cached = _accessTokenCache[trimmed];
      if (cached != null && cached.valid) return cached.token;
    }

    final exchanged = await _exchangeApiKey(trimmed);
    _accessTokenCache[trimmed] = exchanged;
    return exchanged.token;
  }

  Future<_CachedAccessToken> _exchangeApiKey(String apiKey) async {
    final res = await http.post(
      Uri.parse('$_base/auth/exchange_user_api_key'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: '{}',
    );
    if (res.statusCode != 200) {
      final message = _errorMessage(res.body);
      if (res.statusCode == 401 ||
          message.toLowerCase().contains('invalid user api key')) {
        throw Exception('Invalid Cursor API key');
      }
      throw Exception(
        'Cursor auth failed (${res.statusCode})${message.isEmpty ? '' : ': $message'}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final accessToken = body['accessToken'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Cursor auth failed: no access token returned');
    }

    final expiresAtMs =
        _jwtExpMs(accessToken) ??
        DateTime.now().millisecondsSinceEpoch + 3600000;
    return _CachedAccessToken(token: accessToken, expiresAtMs: expiresAtMs);
  }

  static String _errorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message'] as String? ?? '';
    } catch (_) {
      return body.length > 120 ? body.substring(0, 120) : body;
    }
  }

  static int? _jwtExpMs(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is num) return exp.toInt() * 1000;
    } catch (_) {}
    return null;
  }

  @override
  Future<ProviderIdentity> verify(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) throw Exception('Paste a Cursor API key first.');
    if (isApiKey(trimmed) && trimmed.length < 20) {
      throw Exception('Invalid Cursor API key');
    }

    final me = await _rpc(
      'aiserver.v1.DashboardService',
      'GetMe',
      {},
      trimmed,
    );
    final id = me['userId'] ?? me['authId'];
    if (id == null) throw Exception('Invalid Cursor credentials');
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
      _rpc(
        'aiserver.v1.DashboardService',
        'GetAggregatedUsageEvents',
        {},
        token,
      ),
    ]);
    final period = results[0];
    final agg = results[1];

    final plan = period['planUsage'] as Map<String, dynamic>? ?? {};
    final spent = _num(plan['totalSpend']).toDouble();
    final included = _num(plan['includedSpend']).toDouble();
    final bonus = _num(plan['bonusSpend']).toDouble();
    final cycleEnd = _ms(_num(period['billingCycleEnd']));

    final aggs =
        (agg['aggregations'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
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
      models.add(
        ModelUsage(
          model: a['modelIntent'] as String? ?? 'unknown',
          inputTokens: it,
          outputTokens: ot,
          cacheReadTokens: cr,
          cacheWriteTokens: cw,
          costUsd: tc / 100,
        ),
      );
    }
    if (models.isEmpty) {
      inputTokens = _num(agg['totalInputTokens']).toInt();
      outputTokens = _num(agg['totalOutputTokens']).toInt();
    }

    // Auto / API / total percentages are slices of ONE included pool.
    // Bonus spend sits outside that pool and is not a third $70 bar.
    final includedDollars = included / 100;
    final autoPct = (_num(plan['autoPercentUsed']) / 100).clamp(0.0, 1.0);
    final apiPct = (_num(plan['apiPercentUsed']) / 100).clamp(0.0, 1.0);
    final totalPct = (_num(plan['totalPercentUsed']) / 100).clamp(0.0, 1.0);
    final hitLimit = (period['displayMessage'] as String? ?? '')
        .toLowerCase()
        .contains('usage limit');
    final windows = <LimitWindow>[];

    if (includedDollars > 0) {
      windows.add(
        LimitWindow(
          id: 'cursor:included',
          label: 'Included',
          used: includedDollars * totalPct,
          cap: includedDollars,
          resetAt: cycleEnd,
          exceeded: totalPct >= 1.0 || hitLimit,
          kind: LimitKind.budget,
        ),
      );
      windows.add(
        LimitWindow(
          id: 'cursor:auto',
          label: 'Auto models',
          used: includedDollars * autoPct,
          cap: includedDollars,
          resetAt: cycleEnd,
          exceeded: autoPct >= 1.0,
          kind: LimitKind.share,
        ),
      );
      windows.add(
        LimitWindow(
          id: 'cursor:api',
          label: 'API models',
          used: includedDollars * apiPct,
          cap: includedDollars,
          resetAt: cycleEnd,
          exceeded: apiPct >= 1.0,
          kind: LimitKind.share,
        ),
      );
    }
    if (bonus > 0) {
      windows.add(
        LimitWindow(
          id: 'cursor:extra',
          label: 'Extra usage',
          used: bonus / 100,
          cap: 0,
          kind: LimitKind.extra,
        ),
      );
    }

    return ProviderUsage(
      totals: UsageTotals(
        requests: _num(agg['totalRequests']).toInt(),
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

  static int _ms(num v) {
    final n = v.toInt();
    if (n <= 0) return 0;
    if (n < 100000000000) return n * 1000;
    return n;
  }
}
