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
  final ({double costUsd, int requests, int inputTokens, int outputTokens})
  totals;
  final double perDay;

  /// Trailing-window spend from the daily series.
  final double spend7;
  final double spend30;

  /// Cross-account top models by cost, merged from latest snapshots.
  final List<ModelUsage> topModels;

  /// The most urgent budget pool across all accounts (hero gauge).
  final LimitWindow? heroWindow;
  final String? heroAccountLabel;
  final PoolOutlook? heroOutlook;
  final double monthlyBudget;
  final UsageDelta delta;
  final String? error;

  const OverviewState({
    required this.loading,
    required this.accounts,
    required this.series,
    required this.totals,
    required this.perDay,
    this.spend7 = 0,
    this.spend30 = 0,
    this.topModels = const [],
    this.heroWindow,
    this.heroAccountLabel,
    this.heroOutlook,
    this.monthlyBudget = 0,
    this.delta = const UsageDelta(),
    this.error,
  });

  static const empty = OverviewState(
    loading: true,
    accounts: [],
    series: [],
    totals: (costUsd: 0, requests: 0, inputTokens: 0, outputTokens: 0),
    perDay: 0,
  );

  OverviewState copyWith({
    bool? loading,
    List<AccountOverview>? accounts,
    List<({String day, double costUsd})>? series,
    ({double costUsd, int requests, int inputTokens, int outputTokens})? totals,
    double? perDay,
    double? spend7,
    double? spend30,
    List<ModelUsage>? topModels,
    LimitWindow? heroWindow,
    String? heroAccountLabel,
    PoolOutlook? heroOutlook,
    double? monthlyBudget,
    UsageDelta? delta,
    String? error,
    bool clearError = false,
  }) => OverviewState(
    loading: loading ?? this.loading,
    accounts: accounts ?? this.accounts,
    series: series ?? this.series,
    totals: totals ?? this.totals,
    perDay: perDay ?? this.perDay,
    spend7: spend7 ?? this.spend7,
    spend30: spend30 ?? this.spend30,
    topModels: topModels ?? this.topModels,
    heroWindow: heroWindow ?? this.heroWindow,
    heroAccountLabel: heroAccountLabel ?? this.heroAccountLabel,
    heroOutlook: heroOutlook ?? this.heroOutlook,
    monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    delta: delta ?? this.delta,
    error: clearError ? null : error ?? this.error,
  );
}

class OverviewViewModel extends ChangeNotifier {
  final UsageRepository _repo;
  final SyncController _sync;

  OverviewViewModel({
    required UsageRepository repo,
    required SyncController sync,
  }) : _repo = repo,
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
      final delta = await _repo.deltaSincePrevious();
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

      // Trailing-window spend from the daily series.
      final today = DateTime.now().toLocal();
      double sumDays(int days) {
        var sum = 0.0;
        for (final point in series) {
          final d = DateTime.tryParse(point.day)?.toLocal();
          if (d == null) continue;
          if (today.difference(d).inDays < days) sum += point.costUsd;
        }
        return sum;
      }

      // Cross-account model aggregation from latest snapshots.
      final byModel = <String, ModelUsage>{};
      for (final account in accounts) {
        for (final m in account.latest?.models ?? const <ModelUsage>[]) {
          final prev = byModel[m.model];
          byModel[m.model] = ModelUsage(
            model: m.model,
            inputTokens: (prev?.inputTokens ?? 0) + m.inputTokens,
            outputTokens: (prev?.outputTokens ?? 0) + m.outputTokens,
            cacheReadTokens: (prev?.cacheReadTokens ?? 0) + m.cacheReadTokens,
            cacheWriteTokens:
                (prev?.cacheWriteTokens ?? 0) + m.cacheWriteTokens,
            costUsd: (prev?.costUsd ?? 0) + m.costUsd,
          );
        }
      }
      final topModels = byModel.values.toList()
        ..sort((a, b) => b.costUsd.compareTo(a.costUsd));

      final budgetRaw = await _repo.setting('userMonthlyBudget');
      final monthlyBudget = double.tryParse(budgetRaw ?? '') ?? 0;

      _state = OverviewState(
        loading: false,
        accounts: accounts,
        series: series,
        totals: totals,
        perDay: pace.perDay,
        spend7: sumDays(7),
        spend30: sumDays(30),
        topModels: topModels.take(6).toList(),
        heroWindow: hero,
        heroAccountLabel: heroLabel,
        heroOutlook: hero == null
            ? null
            : PoolOutlook.forWindow(hero, pace.perDay),
        monthlyBudget: monthlyBudget,
        delta: delta,
        error: null,
      );
    } catch (e) {
      _state = _state.copyWith(
        loading: false,
        error: conciseError(e.toString()),
      );
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
  String? _error;
  String? get error => _error;

  Future<void> load() async {
    if (_rows.isEmpty) {
      _loading = true;
      notifyListeners();
    }
    try {
      final overviews = await _repo.overviews();
      final rows = <AccountRowView>[];
      for (final o in overviews) {
        final token = await _repo.tokenFor(o.account.key);
        rows.add(
          AccountRowView(data: o, hasToken: token != null && token.isNotEmpty),
        );
      }
      _rows = rows;
      _error = null;
    } catch (e) {
      _error = conciseError(e.toString());
      debugPrint('accounts load failed: $e');
    } finally {
      _loading = false;
    }
    notifyListeners();
  }

  Future<bool> refreshOne(String key) async {
    final target = _rows.where((r) => r.data.account.key == key).toList();
    if (target.isEmpty) return false;
    final result = await _repo.refreshAccount(target.first.data.account);
    await load();
    return result.ok;
  }

  Future<bool> updateToken(String key, String token) async {
    final result = await _repo.updateToken(key, token);
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
  bool _hasSnapshots = false;
  bool get hasSnapshots => _hasSnapshots;
  String? _error;
  String? get error => _error;

  /// Trailing window in days; 0 shows everything.
  int _rangeDays = 30;
  int get rangeDays => _rangeDays;

  Future<void> setRange(int days) async {
    _rangeDays = days;
    await load();
  }

  Future<void> load() async {
    if (_days.isEmpty) {
      _loading = true;
      notifyListeners();
    }
    try {
      final accounts = await _repo.accounts();
      _labels = {for (final a in accounts) a.key: a.label};
      final snapshots = await _repo.recentHistory();
      _hasSnapshots = snapshots.isNotEmpty;
      final cutoff = _rangeDays <= 0
          ? null
          : DateTime.now()
                .toLocal()
                .subtract(Duration(days: _rangeDays))
                .millisecondsSinceEpoch;
      final byDay = <DateTime, List<SnapshotRow>>{};
      for (final s in snapshots) {
        if (cutoff != null && s.capturedAt < cutoff) continue;
        final d = DateTime.fromMillisecondsSinceEpoch(s.capturedAt).toLocal();
        final dayKey = DateTime(d.year, d.month, d.day);
        byDay.putIfAbsent(dayKey, () => []).add(s);
      }
      final days = [
        for (final e in byDay.entries) HistoryDay(day: e.key, entries: e.value),
      ]..sort((a, b) => b.day.compareTo(a.day));
      _days = days;
      _error = null;
    } catch (e) {
      _error = conciseError(e.toString());
      debugPrint('history load failed: $e');
    } finally {
      _loading = false;
    }
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
  final List<({String day, int inputTokens, int outputTokens, int requests})>
  tokenSeries;
  final double tokensPerDay;
  final List<({String day, double costPer1k})> costPer1k;
  final String? token;
  final String? error;

  const AccountDetailState({
    required this.loading,
    this.account,
    this.latest,
    this.history = const [],
    this.series = const [],
    this.perDay = 0,
    this.tokenSeries = const [],
    this.tokensPerDay = 0,
    this.costPer1k = const [],
    this.token,
    this.error,
  });

  AccountDetailState copyWith({
    bool? loading,
    AccountRow? account,
    SnapshotRow? latest,
    List<SnapshotRow>? history,
    List<({String day, double costUsd})>? series,
    double? perDay,
    List<({String day, int inputTokens, int outputTokens, int requests})>?
    tokenSeries,
    double? tokensPerDay,
    List<({String day, double costPer1k})>? costPer1k,
    String? token,
    String? error,
    bool clearError = false,
  }) => AccountDetailState(
    loading: loading ?? this.loading,
    account: account ?? this.account,
    latest: latest ?? this.latest,
    history: history ?? this.history,
    series: series ?? this.series,
    perDay: perDay ?? this.perDay,
    tokenSeries: tokenSeries ?? this.tokenSeries,
    tokensPerDay: tokensPerDay ?? this.tokensPerDay,
    costPer1k: costPer1k ?? this.costPer1k,
    token: token ?? this.token,
    error: clearError ? null : error ?? this.error,
  );
}

class AccountDetailViewModel extends ChangeNotifier {
  final UsageRepository _repo;
  AccountDetailViewModel({required UsageRepository repo}) : _repo = repo;

  AccountDetailState _state = const AccountDetailState(loading: true);
  AccountDetailState get state => _state;

  Future<void> load(String key) async {
    try {
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
      final tokenSeries = await _repo.dailyTokensFor(key);
      final tokenPace = dailyTokenPace(
        tokenSeries
            .map(
              (e) => (
                day: e.day,
                inputTokens: e.inputTokens,
                outputTokens: e.outputTokens,
              ),
            )
            .toList(),
      );
      final costPer1k = costPer1kSeries([
        for (final d in series)
          (
            day: d.day,
            costUsd: d.costUsd,
            inputTokens: tokenSeries
                .where((t) => t.day == d.day)
                .map((t) => t.inputTokens)
                .fold<int>(0, (a, b) => a + b),
            outputTokens: tokenSeries
                .where((t) => t.day == d.day)
                .map((t) => t.outputTokens)
                .fold<int>(0, (a, b) => a + b),
          ),
      ]);
      final token = await _repo.tokenFor(key);
      _state = AccountDetailState(
        loading: false,
        account: account,
        latest: latest,
        history: history,
        series: series,
        perDay: pace.perDay,
        tokenSeries: tokenSeries,
        tokensPerDay: tokenPace.tokensPerDay,
        costPer1k: costPer1k,
        token: token,
      );
    } catch (e) {
      _state = _state.copyWith(
        loading: false,
        error: conciseError(e.toString()),
      );
      debugPrint('account detail load failed: $e');
    }
    notifyListeners();
  }

  Future<bool> refresh() async {
    final account = _state.account;
    if (account == null) return false;
    final result = await _repo.refreshAccount(account);
    await load(account.key);
    if (!result.ok) {
      _state = _state.copyWith(error: conciseError(result.error));
      notifyListeners();
    }
    return result.ok;
  }
}
