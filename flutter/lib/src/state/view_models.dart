/// ViewModels for the three tabs plus add-account and account detail.
///
/// Each ViewModel extends [ChangeNotifier], exposes an immutable snapshot of
/// state, and talks only to the repository / sync controller.
library;

import 'package:flutter/foundation.dart';

import '../data/burn_rate.dart';
import '../data/usage_repository.dart';
import '../providers/types.dart';
import 'sync_controller.dart';

/// Everything the Overview tab renders.
class OverviewState {
  final bool loading;
  final List<AccountOverview> accounts;
  final List<({String day, double costUsd})> series;
  final ({double costUsd, int requests, int inputTokens, int outputTokens}) totals;
  final double perDay;

  /// The most urgent budget pool across all accounts (hero gauge).
  final LimitWindow? heroWindow;
  final String? heroAccountLabel;
  final PoolOutlook? heroOutlook;

  const OverviewState({
    required this.loading,
    required this.accounts,
    required this.series,
    required this.totals,
    required this.perDay,
    this.heroWindow,
    this.heroAccountLabel,
    this.heroOutlook,
  });

  static const empty = OverviewState(
    loading: true,
    accounts: [],
    series: [],
    totals: (costUsd: 0, requests: 0, inputTokens: 0, outputTokens: 0),
    perDay: 0,
  );
}

class OverviewViewModel extends ChangeNotifier {
  final UsageRepository _repo;
  final SyncController _sync;

  OverviewViewModel({required UsageRepository repo, required SyncController sync})
      : _repo = repo,
        _sync = sync {
    _sync.addListener(_onSyncChanged);
  }

  OverviewState _state = OverviewState.empty;
  OverviewState get state => _state;

  void _onSyncChanged() {
    if (!_sync.syncing) load();
  }

  Future<void> load() async {
    try {
      final accounts = await _repo.overviews();
      final series = await _repo.dailySpend();
      final totals = await _repo.totals();
      final pace = dailyPace(series);

      // Hero = highest-fraction non-extra budget window.
      LimitWindow? hero;
      String? heroLabel;
      for (final account in accounts) {
        for (final window in account.windows) {
          if (window.kind == LimitKind.extra || window.cap <= 0) continue;
          if (hero == null ||
              window.fraction > hero.fraction ||
              (window.fraction == hero.fraction &&
                  window.resetAt < hero.resetAt)) {
            hero = window;
            heroLabel = account.account.label;
          }
        }
      }

      _state = OverviewState(
        loading: false,
        accounts: accounts,
        series: series,
        totals: totals,
        perDay: pace.perDay,
        heroWindow: hero,
        heroAccountLabel: heroLabel,
        heroOutlook: hero == null ? null : PoolOutlook.forWindow(hero, pace.perDay),
      );
    } catch (e) {
      // Keep last good data on failure.
      debugPrint('overview load failed: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    super.dispose();
  }
}

/// One row in the Accounts tab.
class AccountRowView {
  final AccountOverview data;
  final bool hasToken;
  const AccountRowView({required this.data, required this.hasToken});
}

class AccountsViewModel extends ChangeNotifier {
  final UsageRepository _repo;
  AccountsViewModel({required UsageRepository repo}) : _repo = repo;

  List<AccountRowView> _rows = [];
  List<AccountRowView> get rows => _rows;
  bool _loading = true;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = false;
    final overviews = await _repo.overviews();
    final rows = <AccountRowView>[];
    for (final o in overviews) {
      final token = await _repo.tokenFor(o.account.key);
      rows.add(AccountRowView(data: o, hasToken: token != null && token.isNotEmpty));
    }
    _rows = rows;
    notifyListeners();
  }

  Future<bool> refreshOne(String key) async {
    final target = _rows.where((r) => r.data.account.key == key).toList();
    if (target.isEmpty) return false;
    final result = await _repo.refreshAccount(target.first.data.account);
    await load();
    return result.ok;
  }

  Future<void> remove(String key) async {
    await _repo.removeAccount(key);
    await load();
  }

  Future<void> rename(String key, String label) async {
    await _repo.renameAccount(key, label.trim());
    await load();
  }
}

/// A single day in the History tab with its snapshots.
class HistoryDay {
  final DateTime day;
  final List<SnapshotRow> entries;
  const HistoryDay({required this.day, required this.entries});
}

class HistoryViewModel extends ChangeNotifier {
  final UsageRepository _repo;
  HistoryViewModel({required UsageRepository repo}) : _repo = repo;

  List<HistoryDay> _days = [];
  List<HistoryDay> get days => _days;
  Map<String, String> _labels = {};
  Map<String, String> get labels => _labels;
  bool _loading = true;
  bool get loading => _loading;

  Future<void> load() async {
    final accounts = await _repo.accounts();
    _labels = {for (final a in accounts) a.key: a.label};
    final snapshots = await _repo.recentHistory();
    final byDay = <DateTime, List<SnapshotRow>>{};
    for (final s in snapshots) {
      final d = DateTime.fromMillisecondsSinceEpoch(s.capturedAt).toLocal();
      final dayKey = DateTime(d.year, d.month, d.day);
      byDay.putIfAbsent(dayKey, () => []).add(s);
    }
    final days = [
      for (final e in byDay.entries)
        HistoryDay(day: e.key, entries: e.value),
    ]..sort((a, b) => b.day.compareTo(a.day));
    _days = days;
    _loading = false;
    notifyListeners();
  }
}

class AccountDetailState {
  final bool loading;
  final AccountRow? account;
  final SnapshotRow? latest;
  final List<SnapshotRow> history;
  final List<({String day, double costUsd})> series;
  final double perDay;
  final String? token;

  const AccountDetailState({
    required this.loading,
    this.account,
    this.latest,
    this.history = const [],
    this.series = const [],
    this.perDay = 0,
    this.token,
  });
}

class AccountDetailViewModel extends ChangeNotifier {
  final UsageRepository _repo;
  AccountDetailViewModel({required UsageRepository repo}) : _repo = repo;

  AccountDetailState _state = const AccountDetailState(loading: true);
  AccountDetailState get state => _state;

  Future<void> load(String key) async {
    final accounts = await _repo.accounts();
    final matches = accounts.where((a) => a.key == key).toList();
    if (matches.isEmpty) {
      _state = const AccountDetailState(loading: false);
      notifyListeners();
      return;
    }
    final account = matches.first;
    final latest = await _repo.snapshotFor(key);
    final history = await _repo.historyFor(key, limit: 30);
    final series = await _repo.dailySpendFor(key);
    final pace = dailyPace(series);
    final token = await _repo.tokenFor(key);
    _state = AccountDetailState(
      loading: false,
      account: account,
      latest: latest,
      history: history,
      series: series,
      perDay: pace.perDay,
      token: token,
    );
    notifyListeners();
  }

  Future<bool> refresh() async {
    final account = _state.account;
    if (account == null) return false;
    final ok = (await _repo.refreshAccount(account)).ok;
    await load(account.key);
    return ok;
  }
}
