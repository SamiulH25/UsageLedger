/// CSV export of snapshot history + per-model lines, shared via the
/// platform share sheet.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/registry.dart';
import 'usage_repository.dart';

String _csvField(Object? v) {
  final s = '$v';
  return s.contains(',') || s.contains('"') || s.contains('\n')
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}

String _iso(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms).toUtc().toIso8601String();

/// Builds the export CSV from the most recent [limit] snapshots.
Future<String> buildExportCsv(UsageRepository repo, {int limit = 500}) async {
  final accounts = await repo.accounts();
  final labels = {for (final a in accounts) a.key: a.label};
  final snapshots = await repo.recentHistory(limit: limit);

  final out = StringBuffer(
    'type,date,account,platform,model,cost_usd,requests,tokens_in,tokens_out\n',
  );
  for (final s in snapshots) {
    final account = _csvField(labels[s.accountKey] ?? s.accountKey);
    final platform = _csvField(providerName(s.platform));
    out.write(
      'snapshot,${_iso(s.capturedAt)},$account,$platform,,'
      '${s.costUsd.toStringAsFixed(4)},${s.requests},'
      '${s.inputTokens},${s.outputTokens}\n',
    );
    for (final m in s.models) {
      out.write(
        'model,${_iso(s.capturedAt)},$account,$platform,${_csvField(m.model)},'
        '${m.costUsd.toStringAsFixed(6)},,${m.inputTokens},${m.outputTokens}\n',
      );
    }
  }
  return out.toString();
}

/// Builds the CSV, writes it to a temp file, and opens the share sheet.
/// Returns the file path (also useful on desktop where sharing is a no-op).
Future<String> exportCsv(UsageRepository repo) async {
  final csv = await buildExportCsv(repo);
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/usageledger_export_$stamp.csv');
  await file.writeAsString(csv);
  await Share.shareXFiles([
    XFile(file.path, mimeType: 'text/csv'),
  ], subject: 'UsageLedger export');
  return file.path;
}
