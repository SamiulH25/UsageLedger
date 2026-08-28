/// Repository — the single source of truth for accounts, snapshots and sync.
///
/// ViewModels talk to this class only; it composes the storage service
/// (db.dart) with the provider registry (REST/Connect clients).
library;

import '../db/db.dart' as db;
import '../db/db.dart' show AccountRow, SnapshotRow;
import '../providers/registry.dart';
import '../providers/types.dart';

export '../db/db.dart' show AccountRow, SnapshotRow;

class RefreshOutcome {
  final int ok;
  final List<RefreshResult> failed;
  const RefreshOutcome({required this.ok, required this.failed});
}

class RefreshResult {
  final bool ok;
  final String account;
  final String? error;
  const RefreshResult({required this.ok, required this.account, this.error});
}

class UsageDelta {
  final double costUsd;
  final int requests;
  final int inputTokens;
  final int outputTokens;

  const UsageDelta({
    this.costUsd = 0,
    this.requests = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  int get tokens => inputTokens + outputTokens;
  bool get isEmpty => costUsd <= 0 && requests <= 0 && tokens <= 0;
}

/// One account joined with its latest snapshot.
class AccountOverview {
  final AccountRow account;
  final SnapshotRow? latest;
  const AccountOverview({required this.account, required this.latest});

  List<LimitWindow> get windows => latest?.windows ?? const [];
}

class UsageRepository {
  static final UsageRepository instance = UsageRepository._();

  UsageRepository._();

  // --- reads ---

  Future<List<AccountRow>> accounts() => db.listAccounts();

  Future<List<AccountOverview>> overviews() async {
    final rows = await db.accountTotals();
    final out = <AccountOverview>[];
    for (final row in rows) {
      out.add(
        AccountOverview(
          account: row.account,
          latest: await db.latestSnapshot(row.account.key),
        ),
      );
    }
    return out;
  }

  Future<SnapshotRow?> snapshotFor(String accountKey) =>
      db.latestSnapshot(accountKey);

  Future<List<SnapshotRow>> historyFor(String accountKey, {int limit = 60}) =>
      db.snapshotHistory(accountKey, limit: limit);

  Future<List<SnapshotRow>> recentHistory({int limit = 200}) =>
      db.recentSnapshots(limit: limit);

  Future<List<({String day, double costUsd})>> dailySpend() => db.dailySpend();

  Future<List<({String day, double costUsd})>> dailySpendFor(
    String accountKey,
  ) => db.dailySpend(accountKey: accountKey);

  Future<List<({String day, int inputTokens, int outputTokens, int requests})>>
  dailyTokens() => db.dailyTokens();

  Future<List<({String day, int inputTokens, int outputTokens, int requests})>>
  dailyTokensFor(String accountKey) => db.dailyTokens(accountKey: accountKey);

  Future<({double costUsd, int requests, int inputTokens, int outputTokens})>
  totals() => db.aggregated();

  /// Difference between each account's two newest snapshots.
  ///
  /// Provider totals are usually period-to-date values. When a provider
  /// resets a period, the newest value is treated as the new delta instead of
  /// producing a negative number.
  Future<UsageDelta> deltaSincePrevious() async {
    final accounts = await db.listAccounts();
    var cost = 0.0;
    var requests = 0;
    var input = 0;
    var output = 0;

    int deltaInt(int current, int previous) =>
        current >= previous ? current - previous : current;
    double deltaCost(double current, double previous) =>
        current >= previous ? current - previous : current;

    for (final account in accounts) {
      final snapshots = await db.snapshotHistory(account.key, limit: 2);
      if (snapshots.length < 2) continue;
      final current = snapshots[0];
      final previous = snapshots[1];
      cost += deltaCost(current.costUsd, previous.costUsd);
      requests += deltaInt(current.requests, previous.requests);
      input += deltaInt(current.inputTokens, previous.inputTokens);
      output += deltaInt(current.outputTokens, previous.outputTokens);
    }
    return UsageDelta(
      costUsd: cost,
      requests: requests,
      inputTokens: input,
      outputTokens: output,
    );
  }

  // --- writes ---

  Future<RefreshOutcome> refreshAll() async {
    final rows = await db.listAccounts();
    final results = await Future.wait(rows.map(refreshAccount));
    return RefreshOutcome(
      ok: results.where((r) => r.ok).length,
      failed: results.where((r) => !r.ok).toList(),
    );
  }

  Future<RefreshResult> refreshAccount(AccountRow account) async {
    try {
      final provider = providerById(account.platform);
      if (provider == null) {
        const error = 'Unknown provider';
        await db.setSyncStatus(account.key, ok: false, error: error);
        return RefreshResult(ok: false, account: account.key, error: error);
      }
      final token = await db.getToken(account.key);
      if (token == null) {
        const error = 'No stored token';
        await db.setSyncStatus(account.key, ok: false, error: error);
        return RefreshResult(ok: false, account: account.key, error: error);
      }
      final usage = await provider.fetchUsage(token);
      await db.saveSnapshot(
        SnapshotRow(
          accountKey: account.key,
          platform: account.platform,
          capturedAt: DateTime.now().millisecondsSinceEpoch,
          requests: usage.totals.requests,
          inputTokens: usage.totals.inputTokens,
          outputTokens: usage.totals.outputTokens,
          costUsd: usage.totals.costUsd,
          windows: usage.windows,
          models: usage.models,
        ),
      );
      await db.setSyncStatus(account.key, ok: true);
      return RefreshResult(ok: true, account: account.key);
    } catch (e) {
      final error = e.toString().replaceFirst('Exception: ', '');
      await db.setSyncStatus(account.key, ok: false, error: error);
      return RefreshResult(ok: false, account: account.key, error: error);
    }
  }

  /// Replace the stored credential for [key] (re-auth flow). Verifies the new
  /// token with the provider before saving; refreshes and returns the result.
  Future<RefreshResult> updateToken(String key, String token) async {
    final accounts = await db.listAccounts();
    AccountRow? account;
    for (final a in accounts) {
      if (a.key == key) account = a;
    }
    if (account == null) {
      return RefreshResult(ok: false, account: key, error: 'Account not found');
    }
    final provider = providerById(account.platform);
    if (provider == null) {
      return RefreshResult(ok: false, account: key, error: 'Unknown provider');
    }
    try {
      await provider.verify(token.trim());
    } catch (e) {
      return RefreshResult(
        ok: false,
        account: key,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
    await db.saveToken(key, token.trim());
    return refreshAccount(account);
  }

  Future<AccountRow> addAccount({
    required String providerId,
    required String token,
  }) async {
    final provider = providerById(providerId);
    if (provider == null) throw Exception('Unknown provider: $providerId');
    final identity = await provider.verify(token.trim());
    final account = AccountRow(
      key: identity.accountKey,
      platform: providerId,
      label: identity.label,
      email: identity.email,
      addedAt: DateTime.now().millisecondsSinceEpoch,
      lastRefreshAt: 0,
    );
    await db.saveToken(account.key, token.trim());
    await db.upsertAccount(account);
    await refreshAccount(account);
    return account;
  }

  Future<void> restoreAccount(AccountRow account, {String? token}) async {
    if (token != null && token.trim().isNotEmpty) {
      await db.saveToken(account.key, token.trim());
    }
    await db.upsertAccount(account);
  }

  Future<void> removeAccount(String key) async {
    await db.deleteToken(key);
    await db.removeAccount(key);
  }

  Future<void> renameAccount(String key, String label) =>
      db.renameAccount(key, label);

  Future<String?> tokenFor(String key) => db.getToken(key);

  // --- settings ---

  Future<String?> setting(String key) => db.getSetting(key);

  Future<void> setSettingValue(String key, String value) =>
      db.setSetting(key, value);
}
