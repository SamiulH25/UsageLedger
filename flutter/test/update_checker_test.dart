import 'dart:convert';

import 'package:ai_usage_monitor/src/services/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('newer tag than current version', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'tag_name': 'v0.8.0',
          'html_url':
              'https://github.com/SamiulH25/UsageLedger/releases/tag/v0.8.0',
        }),
        200,
      ),
    );
    final info = await checkForUpdate('0.7.0', client: client);
    expect(info.newer, isTrue);
    expect(info.latestTag, 'v0.8.0');
  });

  test('same version is not newer', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'tag_name': 'v0.7.0', 'html_url': 'https://example.com'}),
        200,
      ),
    );
    final info = await checkForUpdate('0.7.0', client: client);
    expect(info.newer, isFalse);
  });
}
