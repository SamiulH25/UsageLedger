import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart'
    show databaseFactory, openDatabase, Database, ConflictAlgorithm;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;

import '../providers/types.dart';

class AccountRow {
  final String key;
  final String platform;
  final String label;
  final String email;
  final int addedAt;
  final int lastRefreshAt;

  /// Last sync failure message; empty when the last sync succeeded.
  final String syncError;
  const AccountRow({
    required this.key,
    required this.platform,
    required this.label,
    required this.email,
    required this.addedAt,
    required this.lastRefreshAt,
    this.syncError = '',
  });

  Map<String, Object?> toMap() => {
    'key': key,
    'platform': platform,
    'label': label,
    'email': email,
    'added_at': addedAt,
    'last_refresh_at': lastRefreshAt,
    'sync_error': syncError,
  };

  factory AccountRow.fromMap(Map<String, Object?> m) => AccountRow(
    key: m['key'] as String,
    platform: m['platform'] as String,
    label: m['label'] as String? ?? '',
    email: m['email'] as String? ?? '',
    addedAt: (m['added_at'] as num?)?.toInt() ?? 0,
    lastRefreshAt: (m['last_refresh_at'] as num?)?.toInt() ?? 0,
    syncError: m['sync_error'] as String? ?? '',
  );
}

class SnapshotRow {
  final String accountKey;
  final String platform;
  final int capturedAt;
  final int requests;
  final int inputTokens;
  final int outputTokens;
  final double costUsd;
  final List<LimitWindow> windows;
  final List<ModelUsage> models;
  const SnapshotRow({
    required this.accountKey,
    required this.platform,
    required this.capturedAt,
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
    required this.costUsd,
    required this.windows,
    this.models = const [],
  });
}

class AccountTotalsRow {
  final AccountRow account;
  final double costUsd;
  final int requests;
  final int inputTokens;
  final int outputTokens;
  const AccountTotalsRow({
    required this.account,
    required this.costUsd,
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
  });
}

Database? _db;
String? _overrideDir; // set by tests / seed tool to avoid platform channels

/// Override the data directory (tests / headless seeding). Null resets to default.
void setOverrideDir(String? dir) {
  _overrideDir = dir;
  _db = null;
}

Future<String> _supportDir() async {
  if (_overrideDir != null) return _overrideDir!;
  final dir = await getApplicationSupportDirectory();
  return dir.path;
}

Future<Database> getDb() async {
  if (_db != null) return _db!;
  // Android: the native sqflite plugin registers the factory automatically.
  // Desktop (linux): force the FFI driver since no plugin exists there.
  if (Platform.isLinux) {
    databaseFactory = databaseFactoryFfi;
  }
  final dir = await _supportDir();
  final path = p.join(dir, 'usage.db');
  _db = await openDatabase(
    path,
    version: 4,
    onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) {
        final cols = await db.rawQuery('PRAGMA table_info(usage_snapshot)');
        final has = cols.any((c) => c['name'] == 'models_json');
        if (!has) {
          await db.execute(
            "ALTER TABLE usage_snapshot ADD COLUMN models_json TEXT NOT NULL DEFAULT '[]'",
          );
        }
      }
      if (oldV < 3) {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      }
      if (oldV < 4) {
        await db.execute(
          "ALTER TABLE account ADD COLUMN sync_error TEXT NOT NULL DEFAULT ''",
        );
      }
    },
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE account (
          key TEXT PRIMARY KEY,
          platform TEXT NOT NULL,
          label TEXT NOT NULL DEFAULT '',
          email TEXT NOT NULL DEFAULT '',
          added_at INTEGER NOT NULL DEFAULT 0,
          last_refresh_at INTEGER NOT NULL DEFAULT 0,
          sync_error TEXT NOT NULL DEFAULT ''
        )''');
      await db.execute(
        'CREATE INDEX idx_account_platform ON account(platform)',
      );
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
        'CREATE INDEX idx_snapshot_acct ON usage_snapshot(account_key, captured_at)',
      );
      await db.execute(
        'CREATE INDEX idx_snapshot_time ON usage_snapshot(captured_at)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    },
  );
  return _db!;
}

// --- accounts ---

Future<void> upsertAccount(AccountRow a) async {
  final db = await getDb();
  await db.insert(
    'account',
    a.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<List<AccountRow>> listAccounts() async {
  final db = await getDb();
  final rows = await db.query('account', orderBy: 'added_at');
  return rows.map(AccountRow.fromMap).toList();
}

Future<void> removeAccount(String key) async {
  final db = await getDb();
  await db.transaction((txn) async {
    await txn.delete('account', where: 'key = ?', whereArgs: [key]);
    await txn.delete(
      'usage_snapshot',
      where: 'account_key = ?',
      whereArgs: [key],
    );
  });
}

/// Record a sync outcome: success refreshes [AccountRow.lastRefreshAt] and
/// clears the error; failure stores [error] but keeps the last success time.
Future<void> setSyncStatus(
  String key, {
  required bool ok,
  String? error,
}) async {
  final db = await getDb();
  await db.update(
    'account',
    ok
        ? {
            'last_refresh_at': DateTime.now().millisecondsSinceEpoch,
            'sync_error': '',
          }
        : {'sync_error': error ?? 'Sync failed'},
    where: 'key = ?',
    whereArgs: [key],
  );
}

Future<void> renameAccount(String key, String label) async {
  final db = await getDb();
  await db.update(
    'account',
    {'label': label},
    where: 'key = ?',
    whereArgs: [key],
  );
}

// --- snapshots ---

Future<void> saveSnapshot(SnapshotRow s) async {
  final db = await getDb();
  final id = '${s.accountKey}:${s.capturedAt}';
  await db.insert('usage_snapshot', {
    'id': id,
    'account_key': s.accountKey,
    'platform': s.platform,
    'captured_at': s.capturedAt,
    'requests': s.requests,
    'input_tokens': s.inputTokens,
    'output_tokens': s.outputTokens,
    'cost_usd': s.costUsd,
    'windows_json': jsonEncode(s.windows.map((w) => w.toJson()).toList()),
    'models_json': jsonEncode(s.models.map((m) => m.toJson()).toList()),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<SnapshotRow?> latestSnapshot(String accountKey) async {
  final db = await getDb();
  final rows = await db.query(
    'usage_snapshot',
    where: 'account_key = ?',
    whereArgs: [accountKey],
    orderBy: 'captured_at DESC',
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return _snapshotFromRow(rows.first);
}

Future<List<AccountTotalsRow>> accountTotals() async {
  final db = await getDb();
  final rows = await db.rawQuery('''
    SELECT a.*, s.cost_usd, s.requests, s.input_tokens, s.output_tokens
    FROM account a
    LEFT JOIN usage_snapshot s ON s.id = (
      SELECT id FROM usage_snapshot WHERE account_key = a.key ORDER BY captured_at DESC LIMIT 1
    )
    ORDER BY a.added_at
  ''');
  return rows
      .map(
        (r) => AccountTotalsRow(
          account: AccountRow.fromMap({
            'key': r['key'],
            'platform': r['platform'],
            'label': r['label'],
            'email': r['email'],
            'added_at': r['added_at'],
            'last_refresh_at': r['last_refresh_at'],
            'sync_error': r['sync_error'],
          }),
          costUsd: (r['cost_usd'] as num?)?.toDouble() ?? 0,
          requests: (r['requests'] as num?)?.toInt() ?? 0,
          inputTokens: (r['input_tokens'] as num?)?.toInt() ?? 0,
          outputTokens: (r['output_tokens'] as num?)?.toInt() ?? 0,
        ),
      )
      .toList();
}

Future<({double costUsd, int requests, int inputTokens, int outputTokens})>
aggregated() async {
  final db = await getDb();
  final r = await db.rawQuery('''
    SELECT SUM(cost_usd) as cost_usd, SUM(requests) as requests,
           SUM(input_tokens) as input_tokens, SUM(output_tokens) as output_tokens
    FROM usage_snapshot
    WHERE id IN (SELECT MAX(id) FROM usage_snapshot GROUP BY account_key)
  ''');
  final row = r.isEmpty ? null : r.first;
  return (
    costUsd: (row?['cost_usd'] as num?)?.toDouble() ?? 0,
    requests: (row?['requests'] as num?)?.toInt() ?? 0,
    inputTokens: (row?['input_tokens'] as num?)?.toInt() ?? 0,
    outputTokens: (row?['output_tokens'] as num?)?.toInt() ?? 0,
  );
}

/// Per-day spend: for each account, the day-over-day change of its
/// period-to-date total (clamped at period resets), summed across accounts.
/// The first captured day per account has no baseline and contributes 0.
Future<List<({String day, double costUsd})>> dailySpend({
  String? accountKey,
}) async {
  final db = await getDb();
  final rows = await db.rawQuery('''
    SELECT s.account_key AS account_key, m.day AS day, s.cost_usd AS cost_usd
    FROM usage_snapshot s
    JOIN (
      SELECT account_key,
             strftime('%Y-%m-%d', captured_at / 1000, 'unixepoch', 'localtime') AS day,
             MAX(id) AS id
      FROM usage_snapshot
      ${accountKey == null ? '' : 'WHERE account_key = ?'}
      GROUP BY account_key, day
    ) m ON m.id = s.id
    ORDER BY s.account_key, m.day
    ''', accountKey == null ? const [] : [accountKey]);

  final byDay = <String, double>{};
  String? firstDay;
  String? account;
  String? prevDay;
  var prev = 0.0;
  for (final r in rows) {
    final a = r['account_key'] as String;
    final day = r['day'] as String;
    final cost = (r['cost_usd'] as num?)?.toDouble() ?? 0;
    if (a != account) {
      account = a;
      prevDay = null;
      prev = 0;
    }
    if (prevDay != null && cost > prev) {
      byDay[day] = (byDay[day] ?? 0) + (cost - prev);
    }
    prev = cost;
    prevDay = day;
    firstDay ??= day;
    if (!byDay.containsKey(day)) byDay[day] = 0;
  }
  if (byDay.isEmpty) return const [];

  // Emit every calendar day from first to last capture so zero-spend days
  // still chart as zero bars.
  final lastDay = prevDay!;
  final out = <({String day, double costUsd})>[];
  var cursor = DateTime.parse(firstDay!);
  final end = DateTime.parse(lastDay);
  while (!cursor.isAfter(end)) {
    final key =
        '${cursor.year.toString().padLeft(4, '0')}-'
        '${cursor.month.toString().padLeft(2, '0')}-'
        '${cursor.day.toString().padLeft(2, '0')}';
    out.add((day: key, costUsd: byDay[key] ?? 0));
    cursor = cursor.add(const Duration(days: 1));
  }
  return out;
}

/// Full snapshot history for one account, newest first.
Future<List<SnapshotRow>> snapshotHistory(
  String accountKey, {
  int limit = 60,
}) async {
  final db = await getDb();
  final rows = await db.query(
    'usage_snapshot',
    where: 'account_key = ?',
    whereArgs: [accountKey],
    orderBy: 'captured_at DESC',
    limit: limit,
  );
  return rows.map(_snapshotFromRow).toList();
}

/// Latest snapshot per account per capture moment, newest first (all accounts).
Future<List<SnapshotRow>> recentSnapshots({int limit = 200}) async {
  final db = await getDb();
  final rows = await db.query(
    'usage_snapshot',
    orderBy: 'captured_at DESC',
    limit: limit,
  );
  return rows.map(_snapshotFromRow).toList();
}

SnapshotRow _snapshotFromRow(Map<String, Object?> r) => SnapshotRow(
  accountKey: r['account_key'] as String,
  platform: r['platform'] as String,
  capturedAt: (r['captured_at'] as num).toInt(),
  requests: (r['requests'] as num).toInt(),
  inputTokens: (r['input_tokens'] as num).toInt(),
  outputTokens: (r['output_tokens'] as num).toInt(),
  costUsd: (r['cost_usd'] as num).toDouble(),
  windows: (jsonDecode(r['windows_json'] as String) as List)
      .map((e) => LimitWindow.fromJson(e as Map<String, dynamic>))
      .toList(),
  models: (jsonDecode(r['models_json'] as String? ?? '[]') as List)
      .map((e) => ModelUsage.fromJson(e as Map<String, dynamic>))
      .toList(),
);

// --- settings (key/value) ---

Future<String?> getSetting(String key) async {
  final db = await getDb();
  final rows = await db.query(
    'settings',
    where: 'key = ?',
    whereArgs: [key],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return rows.first['value'] as String?;
}

Future<void> setSetting(String key, String value) async {
  final db = await getDb();
  await db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

// --- token storage: Android Keystore, chmod 600 files on desktop ---

const _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

Future<File> _tokenFile(String accountKey) async {
  final dir = await _supportDir();
  return File(p.join(dir, 'tokens', '$accountKey.token'));
}

/// Mobile platforms keep API keys in the OS keystore/keychain; desktop keeps
/// them in a chmod-600 file under the app support dir.
bool get usesSecureStore => !Platform.isLinux && !Platform.isMacOS;

Future<void> saveToken(String accountKey, String token) async {
  if (usesSecureStore) {
    await _secure.write(key: accountKey, value: token);
    final leftover = await _tokenFile(accountKey);
    if (await leftover.exists()) await leftover.delete();
    return;
  }
  final f = await _tokenFile(accountKey);
  await f.parent.create(recursive: true);
  await f.writeAsString(token, flush: true);
  try {
    // iOS forbids process spawns entirely; macOS sandbox may refuse them.
    if (Platform.isLinux) await Process.run('chmod', ['600', f.path]);
  } catch (_) {}
}

Future<String?> getToken(String accountKey) async {
  if (usesSecureStore) {
    final stored = await _secure.read(key: accountKey);
    if (stored != null && stored.isNotEmpty) return stored;
  }
  final f = await _tokenFile(accountKey);
  if (!await f.exists()) return null;
  return f.readAsString();
}

Future<void> deleteToken(String accountKey) async {
  if (usesSecureStore) {
    await _secure.delete(key: accountKey);
  }
  final f = await _tokenFile(accountKey);
  if (await f.exists()) await f.delete();
}
