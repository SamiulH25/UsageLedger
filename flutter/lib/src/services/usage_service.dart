/// Compatibility shim — the service functions now delegate to the
/// [UsageRepository]. New code should depend on the repository directly.
library;

import '../data/usage_repository.dart';

export '../data/usage_repository.dart'
    show RefreshOutcome, RefreshResult, AccountOverview;

Future<({int ok, List<RefreshResult> failed})> refreshAll() async {
  final r = await UsageRepository.instance.refreshAll();
  return (ok: r.ok, failed: r.failed);
}

Future<RefreshResult> refreshAccount(AccountRow account) =>
    UsageRepository.instance.refreshAccount(account);

Future<void> removeAccountWithToken(String key) =>
    UsageRepository.instance.removeAccount(key);

Future<AccountRow> addAccount({
  required String providerId,
  required String token,
}) => UsageRepository.instance.addAccount(providerId: providerId, token: token);

Future<String?> getToken(String accountKey) =>
    UsageRepository.instance.tokenFor(accountKey);
