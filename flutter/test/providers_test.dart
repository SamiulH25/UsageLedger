import 'dart:convert';

import 'package:ai_usage_monitor/src/providers/commandcode.dart';
import 'package:ai_usage_monitor/src/providers/types.dart';
import 'package:ai_usage_monitor/src/providers/cursor.dart';
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
}
