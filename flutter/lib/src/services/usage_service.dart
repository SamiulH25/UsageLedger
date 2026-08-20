import '../db/db.dart';
import '../providers/registry.dart';

class RefreshResult {
  final bool ok;
  final String account;
  final String? error;
  const RefreshResult({required this.ok, required this.account, this.error});
}

/// Fetch latest usage for every stored account and persist a snapshot.
Future<({int ok, List<RefreshResult> failed})> refreshAll() async {
  final accounts = await listAccounts();
  final results = await Future.wait(accounts.map(refreshAccount));
  return (
    ok: results.where((r) => r.ok).length,
    failed: results.where((r) => !r.ok).toList(),
  );
}

Future<RefreshResult> refreshAccount(AccountRow account) async {
  try {
    final provider = providerById(account.platform);
    if (provider == null) return RefreshResult(ok: false, account: account.key, error: 'Unknown provider');
    final token = await getToken(account.key);
    if (token == null) return RefreshResult(ok: false, account: account.key, error: 'No stored token');
    final usage = await provider.fetchUsage(token);
    await saveSnapshot(SnapshotRow(
      accountKey: account.key,
      platform: account.platform,
      capturedAt: DateTime.now().millisecondsSinceEpoch,
      requests: usage.totals.requests,
      inputTokens: usage.totals.inputTokens,
      outputTokens: usage.totals.outputTokens,
      costUsd: usage.totals.costUsd,
      windows: usage.windows,
      models: usage.models,
    ));
    await upsertAccount(AccountRow(
      key: account.key,
      platform: account.platform,
      label: account.label,
      email: account.email,
      addedAt: account.addedAt,
      lastRefreshAt: DateTime.now().millisecondsSinceEpoch,
    ));
    return RefreshResult(ok: true, account: account.key);
  } catch (e) {
    return RefreshResult(ok: false, account: account.key, error: e.toString());
  }
}

Future<void> removeAccountWithToken(String key) async {
  await deleteToken(key);
  await removeAccount(key);
}

/// Adds an account: verify token, store it (encrypted), persist identity, pull first snapshot.
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
  await saveToken(account.key, token.trim());
  await upsertAccount(account);
  await refreshAccount(account);
  return account;
}
