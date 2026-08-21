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
    final result = await refreshAll();
    if (result.failed.isNotEmpty && mounted) {
      setState(() => _error = 'Sync issue: ${result.failed.first.error}');
    }
    await _load();
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
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
      children: [
        _topBar(),
        const SizedBox(height: 34),
        const Text(
          'Keep every account\nin view.',
          style: TextStyle(
            fontSize: 34,
            height: .98,
            letterSpacing: -1.7,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Connect a provider once, then see spend, limits, and resets in one calm place.',
          style: TextStyle(
            color: AppColors.textDim,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        Card(
          color: AppColors.accent,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start with your first account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Command Code and Cursor are supported.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: widget.onOpenAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add an account'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.accent,
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
      children: [
        _topBar(),
        const SizedBox(height: 23),
        Text(
          _todayLabel(),
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Keep every account\nin view.',
          style: TextStyle(
            fontSize: 31,
            height: .98,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'A simple place to see spend, limits, and resets.',
          style: TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
        const SizedBox(height: 22),
        AttentionBanner(items: hot),
        _summaryCard(tokenCount),
        SectionHeader(
          title: 'Connected accounts',
          trailing: '${_accounts.length} active',
        ),
        for (final account in _accounts) _accountCard(account),
        const SizedBox(height: 4),
        AddAccountCard(onPressed: widget.onOpenAdd),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 11),
            ),
          ),
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

  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'UsageLedger',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        Container(
          width: 31,
          height: 31,
          decoration: const BoxDecoration(
            color: AppColors.text,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'SM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(int tokenCount) {
    return Card(
      color: AppColors.accent,
      child: Padding(
        padding: const EdgeInsets.all(17),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Latest snapshot',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              fmtCost(_agg.costUsd),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w500,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${fmtTokens(tokenCount)} tokens · ${_agg.requests} requests',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .8),
                fontSize: 11,
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
      lastRefreshAt: row.account.lastRefreshAt,
    );
  }
}
