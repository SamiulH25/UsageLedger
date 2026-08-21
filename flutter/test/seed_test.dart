// Seeds the DB with real accounts by driving the app's own services.
// Run: flutter test tool/seed_test.dart --dart-define=CC_TOKEN=... --dart-define=CUR_TOKEN=crsr_...
import 'dart:io';

import 'package:ai_usage_monitor/src/db/db.dart';
import 'package:ai_usage_monitor/src/services/usage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('seed real accounts', () async {
    // Headless: use the FFI sqlite factory and point storage at the real app data dir.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final home = Platform.environment['HOME'] ?? '/home/bob2142';
    final dir = '$home/.local/share/dev.bob2142.ai_usage_monitor';
    setOverrideDir(dir);
    const cc = String.fromEnvironment('CC_TOKEN');
    const cur = String.fromEnvironment('CUR_TOKEN');
    if (cc.isNotEmpty) {
      final a = await addAccount(providerId: 'commandcode', token: cc);
      stdout.writeln('added ${a.platform}: ${a.label} (${a.key})');
    }
    if (cur.isNotEmpty) {
      final a = await addAccount(providerId: 'cursor', token: cur);
      stdout.writeln('added ${a.platform}: ${a.label} (${a.key})');
    }
    final res = await refreshAll();
    stdout.writeln('refresh ok=${res.ok} failed=${res.failed.length}');
    for (final f in res.failed) {
      stdout.writeln('FAILED ${f.account}: ${f.error}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
