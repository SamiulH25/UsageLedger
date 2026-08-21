import 'dart:convert';

import 'package:ai_usage_monitor/src/providers/commandcode.dart';
import 'package:ai_usage_monitor/src/providers/types.dart';
import 'package:ai_usage_monitor/src/providers/cursor.dart';
import 'package:ai_usage_monitor/src/providers/openai.dart';
import 'package:ai_usage_monitor/src/providers/openrouter.dart';
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
  group('CommandCodeProvider', () {
    late http.Client client;
    late CommandCodeProvider provider;

    setUp(() {
      client = MockClient((req) async {
        switch (req.url.path) {
          case '/alpha/whoami':
            return _json({
              'success': true,
              'user': {
                'id': 'u123',
                'userName': 'SamiulH25',
                'email': 's@example.com',
              },
            });
          case '/alpha/billing/credits':
            return _json({
              'credits': {'monthlyCredits': 45.2},
              'windowLimits': {
                'fiveHour': {
                  'used': 0.01,
                  'cap': 14,
                  'resetAt': 1756000000,
                  'exceeded': false,
                },
                'weekly': {
                  'used': 24.57,
                  'cap': 35,
                  'resetAt': 1756100000,
                  'exceeded': false,
                },
              },
            });
          case '/alpha/billing/subscriptions':
            return _json({
              'data': {
                'currentPeriodStart': '2026-08-01T00:00:00Z',
                'currentPeriodEnd': '2026-09-15T00:00:00Z',
              },
            });
          case '/alpha/usage/summary':
            return _json({
              'totalMonthlyCredits': 24.8,
              'totalCost': 24.8,
              'totalCount': 7358,
              'totalTokensIn': 1501750000,
              'totalTokensOut': 3320000,
            });
          default:
            return http.Response('not found', 404);
        }
      });
      provider = CommandCodeProvider(client: client);
    });

    test('verify maps whoami to an identity', () async {
      final id = await provider.verify('user_key');
      expect(id.accountKey, 'cc:u123');
      expect(id.label, 'SamiulH25');
      expect(id.email, 's@example.com');
    });

    test('fetchUsage parses weekly, burst, and monthly windows', () async {
      final usage = await provider.fetchUsage('user_key');
      expect(usage.windows, hasLength(3));
      final weekly = usage.windows.firstWhere(
        (w) => w.id == 'commandcode:weekly',
      );
      expect(weekly.used, 24.57);
      expect(weekly.cap, 35);
      expect(weekly.kind, LimitKind.budget);
      final burst = usage.windows.firstWhere((w) => w.id == 'commandcode:5h');
      expect(burst.kind, LimitKind.burst);
      // Monthly: period spend 24.8 + remaining 45.2 = 70 cap.
      final monthly = usage.windows.firstWhere(
        (w) => w.id == 'commandcode:monthly',
      );
      expect(monthly.used, closeTo(24.8, 0.001));
      expect(monthly.cap, closeTo(70.0, 0.001));
      expect(monthly.resetAt, isNonZero);
    });

    test('totals come from the usage summary', () async {
      final usage = await provider.fetchUsage('user_key');
      expect(usage.totals.requests, 7358);
      expect(usage.totals.inputTokens, 1501750000);
      expect(usage.totals.costUsd, closeTo(24.8, 0.001));
    });

    test('non-200 raises with status code', () async {
      final failing = CommandCodeProvider(
        client: MockClient((req) async => http.Response('nope', 500)),
      );
      await expectLater(failing.fetchUsage('user_key'), throwsException);
    });
  });

  group('CursorProvider', () {
    late CursorProvider provider;

    setUp(() {
      final client = MockClient((req) async {
        switch (req.url.path) {
          case '/auth/exchange_user_api_key':
            return _json({'accessToken': 'header.payload.sig'});
          case '/aiserver.v1.DashboardService/GetMe':
            return _json({
              'userId': 'u99',
              'firstName': 'Samiul',
              'lastName': 'Hossain',
              'email': 's@x.com',
            });
          case '/aiserver.v1.DashboardService/GetCurrentPeriodUsage':
            // int64 fields arrive as strings from the Connect gateway.
            return _json({
              'planUsage': {
                'totalSpend': '85600',
                'includedSpend': '7000',
                'bonusSpend': '78600',
                'autoPercentUsed': 98,
                'apiPercentUsed': 64,
                'totalPercentUsed': 94,
              },
              'autoBucketModels': ['auto-mode'],
              'billingCycleEnd': '1756100000',
              'displayMessage': '',
              'spendLimitUsage': {
                'limitType': 'individual',
                'individualLimit': '5000',
                'individualUsed': '1200',
                'pooledLimit': '0',
                'pooledUsed': '0',
              },
            });
          case '/aiserver.v1.DashboardService/GetPlanInfo':
            return _json({
              'planInfo': {'planName': 'Pro', 'includedAmountCents': 7000},
            });
          case '/aiserver.v1.DashboardService/GetAggregatedUsageEvents':
            return _json({
              'aggregations': [
                {
                  'modelIntent': 'auto-mode',
                  'inputTokens': '1000',
                  'outputTokens': '200',
                  'cacheReadTokens': '50',
                  'cacheWriteTokens': '10',
                  'totalCents': '120',
                },
                {
                  'modelIntent': 'gpt-x',
                  'inputTokens': 500,
                  'outputTokens': 100,
                  'cacheReadTokens': 0,
                  'cacheWriteTokens': 0,
                  'totalCents': 300,
                },
              ],
              'totalRequests': 42,
              'totalInputTokens': 1500,
              'totalOutputTokens': 300,
            });
          default:
            return http.Response('not found', 404);
        }
      });
      provider = CursorProvider(client: client);
    });

    test('verify exchanges an API key and maps GetMe', () async {
      final id = await provider.verify('crsr_${'x' * 24}');
      expect(id.accountKey, 'cursor:u99');
      expect(id.label, 'Samiul Hossain');
    });

    test(
      'included pool and share windows derive from plan percentages',
      () async {
        final usage = await provider.fetchUsage('crsr_${'x' * 24}');
        final included = usage.windows.firstWhere(
          (w) => w.id == 'cursor:included',
        );
        expect(included.used, closeTo(70 * 0.94, 0.001));
        expect(included.cap, closeTo(70, 0.001));
        final auto = usage.windows.firstWhere((w) => w.id == 'cursor:auto');
        expect(auto.used, closeTo(70 * 0.98, 0.001));
        expect(auto.kind, LimitKind.share);
        final api = usage.windows.firstWhere((w) => w.id == 'cursor:api');
        expect(api.used, closeTo(70 * 0.64, 0.001));
        final extra = usage.windows.firstWhere((w) => w.id == 'cursor:extra');
        expect(extra.used, closeTo(786, 0.001));
        expect(extra.kind, LimitKind.extra);
      },
    );

    test('int64-as-string fields coerce to numbers', () async {
      final usage = await provider.fetchUsage('crsr_${'x' * 24}');
      expect(usage.models.first.inputTokens, 1000);
      expect(usage.totals.costUsd, closeTo(856, 0.001));
      expect(usage.totals.requests, 42);
      expect(usage.windows.first.resetAt, 1756100000000);
    });

    test('model buckets follow autoBucketModels', () async {
      final usage = await provider.fetchUsage('crsr_${'x' * 24}');
      expect(usage.models.first.bucket, 'auto');
      expect(usage.models.last.bucket, 'api');
      expect(usage.models.first.costUsd, closeTo(1.2, 0.001));
    });

    test(
      'GetPlanInfo prefixes included label and adds on-demand window',
      () async {
        final usage = await provider.fetchUsage('crsr_${'x' * 24}');
        final included = usage.windows.firstWhere(
          (w) => w.id == 'cursor:included',
        );
        expect(included.label, 'Pro included');
        final ondemand = usage.windows.firstWhere(
          (w) => w.id == 'cursor:ondemand',
        );
        expect(ondemand.label, 'On-demand');
        expect(ondemand.used, closeTo(12, 0.001));
        expect(ondemand.cap, closeTo(50, 0.001));
        expect(ondemand.kind, LimitKind.budget);
      },
    );

    test('rejected key surfaces a clear error', () async {
      final rejecting = CursorProvider(
        client: MockClient(
          (req) async => req.url.path.endsWith('exchange_user_api_key')
              ? http.Response('{"message":"Invalid user api key"}', 401)
              : http.Response('{}', 401),
        ),
      );
      await expectLater(
        rejecting.verify('crsr_${'x' * 24}'),
        throwsA(
          predicate((e) => e.toString().contains('Invalid Cursor API key')),
        ),
      );
    });
  });
  group('OpenRouterProvider', () {
    late OpenRouterProvider provider;
    setUp(() {
      final client = MockClient((req) async {
        switch (req.url.path) {
          case '/api/v1/key':
            return _json({
              'data': {
                'label': 'my-key',
                'limit': 20,
                'usage': 4.5,
                'limit_remaining': 15.5,
                'usage_daily': 1.2,
              },
            });
          case '/api/v1/credits':
            return _json({
              'data': {'total_credits': 100.5, 'total_usage': 25.75},
            });
          case '/api/v1/activity':
            return _json({
              'data': [
                {
                  'date': '2026-08-20',
                  'model': 'openai/gpt-5.2',
                  'usage': 1.25,
                  'requests': 12,
                  'prompt_tokens': 900,
                  'completion_tokens': 300,
                  'reasoning_tokens': 100,
                },
                {
                  'date': '2026-08-21',
                  'model': 'openai/gpt-5.2',
                  'usage': 0.75,
                  'requests': 8,
                  'prompt_tokens': 400,
                  'completion_tokens': 200,
                  'reasoning_tokens': 0,
                },
                {
                  'date': '2026-08-21',
                  'model': 'anthropic/claude-opus-4.6',
                  'usage': 3.0,
                  'requests': 2,
                  'prompt_tokens': 500,
                  'completion_tokens': 150,
                  'reasoning_tokens': 50,
                },
              ],
            });
          default:
            return http.Response('not found', 404);
        }
      });
      provider = OpenRouterProvider(client: client);
    });

    test('verify derives a stable account key from the token', () async {
      final id = await provider.verify('sk-or-v1-abc');
      expect(id.accountKey, startsWith('openrouter:'));
      expect(id.label, 'my-key');
    });

    test('credits and key quota become budget windows', () async {
      final usage = await provider.fetchUsage('sk-or-v1-abc');
      final credits = usage.windows.firstWhere(
        (w) => w.id == 'openrouter:credits',
      );
      expect(credits.used, 25.75);
      expect(credits.cap, 100.5);
      final quota = usage.windows.firstWhere((w) => w.id == 'openrouter:key');
      expect(quota.used, 4.5);
      expect(quota.cap, 20);
    });

    test('activity rows aggregate per model with reasoning tokens', () async {
      final usage = await provider.fetchUsage('sk-or-v1-abc');
      expect(usage.models, hasLength(2));
      final gpt = usage.models.firstWhere((m) => m.model.contains('gpt'));
      expect(gpt.costUsd, closeTo(2.0, 0.001));
      expect(gpt.inputTokens, 1300);
      // completion + reasoning collapse into output.
      expect(gpt.outputTokens, 600);
      expect(usage.totals.requests, 22);
      expect(usage.totals.costUsd, 25.75);
    });

    test('usage_daily from /key becomes a Today window', () async {
      final usage = await provider.fetchUsage('sk-or-v1-abc');
      final today = usage.windows.firstWhere((w) => w.id == 'openrouter:day');
      expect(today.label, 'Today');
      expect(today.used, closeTo(1.2, 0.001));
      expect(today.cap, 0);
      expect(today.kind, LimitKind.extra);
    });

    test(
      'regular keys degrade to key-quota only (403 on credits + activity)',
      () async {
        final limited = OpenRouterProvider(
          client: MockClient((req) async {
            if (req.url.path == '/api/v1/credits' ||
                req.url.path == '/api/v1/activity') {
              return _json({
                'error': {'code': 403, 'message': 'Only management keys'},
              }, status: 403);
            }
            if (req.url.path == '/api/v1/key') {
              return _json({
                'data': {'label': 'k', 'limit': 20.0, 'usage': 2.0},
              });
            }
            return http.Response('not found', 404);
          }),
        );
        final usage = await limited.fetchUsage('sk-or-v1-abc');
        expect(
          usage.windows.where((w) => w.id == 'openrouter:credits'),
          isEmpty,
        );
        expect(
          usage.windows.where((w) => w.id == 'openrouter:key'),
          isNotEmpty,
        );
        expect(usage.totals.costUsd, 2.0);
        // No token history exists for regular keys — must not crash the sync.
        expect(usage.models, isEmpty);
        expect(usage.totals.inputTokens, 0);
        expect(usage.totals.outputTokens, 0);
      },
    );
  });

  group('OpenAiProvider', () {
    late OpenAiProvider provider;
    setUp(() {
      final client = MockClient((req) async {
        final path = req.url.path;
        if (path == '/v1/organization/costs') {
          if (req.url.queryParameters['page'] == null) {
            return _json({
              'object': 'page',
              'data': [
                {
                  'object': 'bucket',
                  'start_time': 1755561600,
                  'results': [
                    {
                      'object': 'organization.costs.result',
                      'amount': {'value': 1.5, 'currency': 'usd'},
                      'line_item': 'GPT-5.2',
                    },
                    {
                      'object': 'organization.costs.result',
                      'amount': {'value': 0.25, 'currency': 'usd'},
                      'line_item': 'Embeddings',
                    },
                  ],
                },
              ],
              'has_more': true,
              'next_page': 'p2',
            });
          }
          return _json({
            'object': 'page',
            'data': [
              {
                'object': 'bucket',
                'start_time': 1755648000,
                'results': [
                  {
                    'object': 'organization.costs.result',
                    'amount': {'value': 0.5, 'currency': 'usd'},
                    'line_item': 'GPT-5.2',
                  },
                ],
              },
            ],
            'has_more': false,
            'next_page': null,
          });
        }
        if (path == '/v1/organization/usage/completions') {
          return _json({
            'object': 'page',
            'data': [
              {
                'object': 'bucket',
                'start_time': 1755561600,
                'results': [
                  {
                    'object': 'organization.usage.completions.result',
                    'input_tokens': 1200,
                    'output_tokens': 340,
                    'num_model_requests': 9,
                    'model': 'gpt-5.2',
                  },
                ],
              },
            ],
            'has_more': false,
            'next_page': null,
          });
        }
        if (path == '/v1/organization/usage/embeddings') {
          return _json({
            'object': 'page',
            'data': [
              {
                'object': 'bucket',
                'start_time': 1755561600,
                'results': [
                  {
                    'object': 'organization.usage.embeddings.result',
                    'input_tokens': 200,
                    'output_tokens': 60,
                    'num_model_requests': 3,
                    'model': 'text-embedding-4',
                  },
                ],
              },
            ],
            'has_more': false,
            'next_page': null,
          });
        }
        return http.Response('not found', 404);
      });
      provider = OpenAiProvider(client: client);
    });

    test('verify probes the costs endpoint', () async {
      final id = await provider.verify('sk-admin-x');
      expect(id.accountKey, 'openai:org');
    });

    test('month cost paginates and becomes an uncapped window', () async {
      final usage = await provider.fetchUsage('sk-admin-x');
      final month = usage.windows.firstWhere((w) => w.id == 'openai:month');
      expect(month.used, closeTo(2.25, 0.001));
      expect(month.cap, 0);
      expect(month.kind, LimitKind.extra);
      expect(usage.totals.costUsd, closeTo(2.25, 0.001));
    });

    test('per-model tokens aggregate across buckets', () async {
      final usage = await provider.fetchUsage('sk-admin-x');
      final gpt = usage.models.firstWhere((m) => m.model == 'gpt-5.2');
      expect(gpt.inputTokens, 1200);
      expect(gpt.outputTokens, 340);
      final embed = usage.models.firstWhere(
        (m) => m.model == 'text-embedding-4',
      );
      expect(embed.inputTokens, 200);
      expect(embed.outputTokens, 60);
      expect(usage.totals.requests, 12);
    });

    test('unmatched cost line items become model rows', () async {
      final usage = await provider.fetchUsage('sk-admin-x');
      final embeddings = usage.models.firstWhere(
        (m) => m.model == 'Embeddings',
      );
      expect(embeddings.costUsd, closeTo(0.25, 0.001));
      expect(embeddings.inputTokens, 0);
      expect(embeddings.outputTokens, 0);
    });

    test('project keys get an admin-key error', () async {
      final rejecting = OpenAiProvider(
        client: MockClient(
          (req) async => _json({
            'error': {'message': 'Missing scopes: api.usage.read.'},
          }, status: 403),
        ),
      );
      await expectLater(
        rejecting.verify('sk-proj-x'),
        throwsA(predicate((e) => e.toString().contains('Admin key'))),
      );
    });
  });
}
