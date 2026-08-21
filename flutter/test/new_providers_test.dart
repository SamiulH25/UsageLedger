import 'dart:convert';

import 'package:ai_usage_monitor/src/providers/anthropic.dart';
import 'package:ai_usage_monitor/src/providers/deepseek.dart';
import 'package:ai_usage_monitor/src/providers/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('AnthropicProvider', () {
    late AnthropicProvider provider;

    setUp(() {
      final client = MockClient((req) async {
        final path = req.url.path;
        if (path == '/v1/organizations/cost_report') {
          return _json({
            'data': [
              {
                'results': [
                  {
                    'amount': {'value': 1.5, 'currency': 'usd'},
                  },
                  {'cost_usd': 0.75},
                ],
              },
            ],
          });
        }
        if (path == '/v1/organizations/usage_report/messages') {
          return _json({
            'data': [
              {
                'results': [
                  {
                    'model': 'claude-sonnet-4',
                    'input_tokens': 1000,
                    'output_tokens': 200,
                    'cache_read_input_tokens': 50,
                    'cache_creation_input_tokens': 10,
                    'num_model_requests': 7,
                  },
                  {
                    'model': 'claude-opus-4',
                    'input_tokens': '300',
                    'output_tokens': '100',
                    'num_model_requests': '2',
                  },
                ],
              },
            ],
          });
        }
        return http.Response('not found', 404);
      });
      provider = AnthropicProvider(client: client);
    });

    test('verify probes cost_report and returns org identity', () async {
      final id = await provider.verify('sk-ant-admin-test');
      expect(id.accountKey, 'anthropic:org');
      expect(id.label, 'Anthropic');
    });

    test('fetchUsage sums costs and aggregates tokens by model', () async {
      final usage = await provider.fetchUsage('sk-ant-admin-test');
      final month = usage.windows.firstWhere((w) => w.id == 'anthropic:month');
      expect(month.used, closeTo(2.25, 0.001));
      expect(month.cap, 0);
      expect(month.kind, LimitKind.extra);
      expect(usage.totals.costUsd, closeTo(2.25, 0.001));
      expect(usage.totals.requests, 9);
      expect(usage.totals.inputTokens, 1300);
      expect(usage.totals.outputTokens, 300);

      final sonnet = usage.models.firstWhere(
        (m) => m.model == 'claude-sonnet-4',
      );
      expect(sonnet.inputTokens, 1000);
      expect(sonnet.outputTokens, 200);
      expect(sonnet.cacheReadTokens, 50);
      expect(sonnet.cacheWriteTokens, 10);
    });

    test('regular keys get an admin-key error on 403', () async {
      final rejecting = AnthropicProvider(
        client: MockClient(
          (req) async => _json({
            'error': {'message': 'Admin API key required'},
          }, status: 403),
        ),
      );
      await expectLater(
        rejecting.verify('sk-ant-api-test'),
        throwsA(predicate((e) => e.toString().contains('Admin key'))),
      );
    });
  });

  group('DeepSeekProvider', () {
    late DeepSeekProvider provider;

    setUp(() {
      final client = MockClient((req) async {
        if (req.url.path == '/user/balance') {
          return _json({
            'is_available': true,
            'balance_infos': [
              {
                'currency': 'USD',
                'total_balance': '75.50',
                'granted_balance': '100.00',
                'topped_up_balance': '0.00',
              },
            ],
          });
        }
        return http.Response('not found', 404);
      });
      provider = DeepSeekProvider(client: client);
    });

    test('verify derives a stable account key from the token', () async {
      final id = await provider.verify('sk-deepseek-abc');
      expect(id.accountKey, startsWith('deepseek:'));
      expect(id.label, 'DeepSeek');
    });

    test('fetchUsage maps prepaid balance like OpenRouter credits', () async {
      final usage = await provider.fetchUsage('sk-deepseek-abc');
      final credits = usage.windows.firstWhere(
        (w) => w.id == 'deepseek:balance',
      );
      expect(credits.label, 'Credits');
      expect(credits.kind, LimitKind.budget);
      expect(credits.cap, closeTo(100.0, 0.001));
      expect(credits.used, closeTo(24.5, 0.001));
      expect(usage.totals.costUsd, closeTo(24.5, 0.001));
    });

    test('remaining-only balance shows full pool with zero used', () async {
      final remaining = DeepSeekProvider(
        client: MockClient(
          (req) async => _json({
            'is_available': true,
            'balance_infos': [
              {
                'currency': 'USD',
                'total_balance': '42.00',
                'granted_balance': '0',
                'topped_up_balance': '0',
              },
            ],
          }),
        ),
      );
      final usage = await remaining.fetchUsage('sk-test');
      final credits = usage.windows.single;
      expect(credits.cap, closeTo(42.0, 0.001));
      expect(credits.used, 0);
    });

    test('non-200 raises with status code', () async {
      final failing = DeepSeekProvider(
        client: MockClient((req) async => http.Response('nope', 500)),
      );
      await expectLater(failing.fetchUsage('sk-test'), throwsException);
    });
  });
}
