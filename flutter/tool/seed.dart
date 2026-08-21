// Seed the app database with real accounts by driving the app's own services.
// Usage: dart run tool/seed.dart <commandcode-token> <cursor-api-key-or-token>
import 'dart:io';

import 'package:ai_usage_monitor/src/services/usage_service.dart';

Future<void> main(List<String> args) async {
  final cc = args.isNotEmpty ? args[0] : null;
  final cur = args.length > 1 ? args[1] : null;
  if (cc != null && cc.isNotEmpty) {
    final a = await addAccount(providerId: 'commandcode', token: cc);
    stdout.writeln('added ${a.platform}: ${a.label} (${a.key})');
  }
  if (cur != null && cur.isNotEmpty) {
    final a = await addAccount(providerId: 'cursor', token: cur);
    stdout.writeln('added ${a.platform}: ${a.label} (${a.key})');
  }
  final res = await refreshAll();
  stdout.writeln('refresh ok=${res.ok} failed=${res.failed.length}');
  exit(0);
}
