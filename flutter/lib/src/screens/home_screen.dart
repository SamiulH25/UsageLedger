import 'package:flutter/material.dart';

import '../db/db.dart';
import '../providers/types.dart';
import '../services/usage_service.dart';
import '../ui/cost_chart.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenAdd;

  const HomeScreen({super.key, required this.onOpenAdd});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _AccountView {
  final AccountTotalsRow totals;
  final SnapshotRow? snap;
  const _AccountView({required this.totals, this.snap});

  List<LimitWindow> get windows => snap?.windows ?? const [];
}

class _HomeScreenState extends State<HomeScreen> {
  List<_AccountView> _accounts = [];
  List<({String day, double costUsd})> _series = [];
  ({double costUsd, int requests, int inputTokens, int outputTokens}) _agg = (
    costUsd: 0,
    requests: 0,
    inputTokens: 0,
    outputTokens: 0,
  );
  String? _error;
  bool _refreshing = false;

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[now.weekday]}, ${months[now.month]} ${now.day}';
  }

  Future<void> _load() async {
    final agg = await aggregated();
    final series = await snapshotSeries();
    final accounts = await accountTotals();
    final views = <_AccountView>[];
    for (final account in accounts) {
      views.add(
        _AccountView(
          totals: account,
          snap: await latestSnapshot(account.account.key),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _agg = agg;
      _series = series;
      _accounts = views;
      _error = null;
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final result = await refreshAll();
    if (result.failed.isNotEmpty && mounted) {
      setState(() => _error = 'Sync issue: ${result.failed.first.error}');
    }
    await _load();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _refresh,
          child: _accounts.isEmpty ? _empty() : _content(),
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal + 4,
        20,
        AppSpacing.pageHorizontal + 4,
        AppSpacing.pageBottom,
      ),
      children: [
        AppBrandBar(
          actions: [
            IconButton(
              onPressed: _refreshing ? null : _refresh,
              tooltip: 'Refresh',
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const PageHeading(
          title: 'Keep every account\nin view.',
          subtitle:
              'Connect a provider once, then see spend, limits, and resets in one calm place.',
        ),
        const SizedBox(height: 24),
        EmptyState(
          icon: Icons.link_outlined,
          title: 'No accounts yet',
          hint:
              'Add Command Code or Cursor to start tracking usage on this device.',
          action: FilledButton.icon(
            onPressed: widget.onOpenAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add an account'),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    final tokenCount = _agg.inputTokens + _agg.outputTokens;
    final hot = <(String, LimitWindow)>[];
    for (final account in _accounts) {
      for (final window in account.windows) {
        if (window.kind == LimitKind.extra) continue;
        if (window.hot) hot.add((account.totals.account.label, window));
      }
    }
    hot.sort((a, b) => b.$2.fraction.compareTo(a.$2.fraction));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        16,
        AppSpacing.pageHorizontal,
        AppSpacing.pageBottom,
      ),
      children: [
        AppBrandBar(
          actions: [
            IconButton(
              onPressed: _refreshing ? null : _refresh,
              tooltip: 'Refresh all accounts',
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(_todayLabel(), style: AppText.eyebrow),
        const SizedBox(height: 6),
        const PageHeading(
          title: 'Overview',
          subtitle: 'Pull down anywhere to refresh usage from your accounts.',
        ),
        const SizedBox(height: 18),
        AttentionBanner(items: hot),
        _summaryCard(tokenCount),
        SectionHeader(
          title: 'Connected accounts',
          trailing: '${_accounts.length} active',
        ),
        for (final account in _accounts) _accountCard(account),
        const SizedBox(height: 4),
        AddAccountCard(onPressed: widget.onOpenAdd),
        if (_error != null) ...[
          const SizedBox(height: 14),
          InlineMessage.error(_error!),
        ],
        if (_series.length >= 2) ...[
          const SectionHeader(title: 'Spend over time'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: SizedBox(height: 150, child: CostChart(series: _series)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryCard(int tokenCount) {
    return Card(
      color: AppColors.accent,
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ALL ACCOUNTS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Latest snapshot',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              fmtCost(_agg.costUsd),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${fmtTokens(tokenCount)} tokens · ${_agg.requests} requests',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .82),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(_AccountView view) {
    final row = view.totals;
    return AccountUsageCard(
      account: row.account,
      costUsd: row.costUsd,
      requests: row.requests,
      inputTokens: row.inputTokens,
      outputTokens: row.outputTokens,
      windows: view.windows,
      models: view.snap?.models ?? const [],
      lastRefreshAt: row.account.lastRefreshAt,
    );
  }
}
