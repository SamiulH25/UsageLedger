import 'dart:io';

import 'package:ai_usage_monitor/src/db/db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a v3-schema database (pre sync_error) so the app's onUpgrade path
/// runs when getDb() opens it at version 4.
Future<void> _seedV3(String dir) async {
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(
    p.join(dir, 'usage.db'),
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE account (
            key TEXT PRIMARY KEY,
            platform TEXT NOT NULL,
            label TEXT NOT NULL DEFAULT '',
            email TEXT NOT NULL DEFAULT '',
            added_at INTEGER NOT NULL DEFAULT 0,
            last_refresh_at INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE usage_snapshot (
            id TEXT PRIMARY KEY,
            account_key TEXT NOT NULL,
            platform TEXT NOT NULL,
            captured_at INTEGER NOT NULL,
            requests INTEGER NOT NULL DEFAULT 0,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cost_usd REAL NOT NULL DEFAULT 0,
            windows_json TEXT NOT NULL DEFAULT '[]',
            models_json TEXT NOT NULL DEFAULT '[]'
          )''');
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    ),
  );
  await db.insert('account', {
    'key': 'cc:u1',
    'platform': 'commandcode',
    'label': 'Old row',
    'email': 'old@example.com',
    'added_at': 1,
    'last_refresh_at': 2,
  });
  await db.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ul_migration');
    setOverrideDir(temp.path);
    await _seedV3(temp.path);
  });

  tearDown(() async {
    setOverrideDir(null);
    await temp.delete(recursive: true);
  });

  test('v3 → v4 migration adds sync_error and preserves rows', () async {
    final db = await getDb();
    final cols = await db.rawQuery('PRAGMA table_info(account)');
    expect(cols.any((c) => c['name'] == 'sync_error'), isTrue);

    final accounts = await listAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.first.syncError, '');
    expect(accounts.first.label, 'Old row');
  });

  test('setSyncStatus stores failures and clears on success', () async {
    await getDb();

    await setSyncStatus('cc:u1', ok: false, error: 'Invalid Cursor API key');
    var row = (await listAccounts()).first;
    expect(row.syncError, 'Invalid Cursor API key');
    expect(row.lastRefreshAt, 2, reason: 'failures keep the last success time');

    await setSyncStatus('cc:u1', ok: true);
    row = (await listAccounts()).first;
    expect(row.syncError, '');
    expect(row.lastRefreshAt, greaterThan(2));
  });
}
