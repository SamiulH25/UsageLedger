import 'package:flutter/material.dart';

import '../db/db.dart' show SnapshotRow;
import '../providers/types.dart';
import '../state/app_scope.dart';
import '../state/view_models.dart';
import '../ui/cost_chart.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Per-account instrument panel: every window, model table, trend, history.
class AccountDetailScreen extends StatefulWidget {
  final String accountKey;

  const AccountDetailScreen({super.key, required this.accountKey});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late final AccountDetailViewModel _vm;

  @override
  void initState() {
    super.initState();
    // Non-dependent lookup: safe inside initState (unlike AppScope.of).
    final scope = context.getInheritedWidgetOfExactType<AppScope>()!;
    _vm = AccountDetailViewModel(repo: scope.repository);
    _vm.load(widget.accountKey);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final state = _vm.state;
        final account = state.account;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              account?.label ?? 'Account',
              style: const TextStyle(fontFamily: displayFamily, fontWeight: FontWeight.w700),
            ),
          ),
          body: state.loading || account == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    final scope = AppScope.of(context);
                    await _vm.refresh();
                    await scope.accountsVm.load();
                    await scope.overviewVm.load();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal, 8, AppSpacing.pageHorizontal, AppSpacing.pageBottom,
                    ),
                    children: [
                      _header(state),
                      if (state.latest != null) ...[
                        const SectionHeader(title: 'Pools'),
                        for (final window in _orderedWindows(state.latest!.windows))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: PoolGauge(
                              window: window,
                              paceCaretFraction: _caret(window, state.perDay),
                            ),
                          ),
                      ],
                      if (state.series.length >= 2) ...[
                        const SectionHeader(title: 'Trend'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Sparkline(values: state.series.map((e) => e.costUsd).toList()),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      state.series.first.day.substring(5),
                                      style: AppText.data(size: 9, color: AppColors.textDim),
                                    ),
                                    Text(
                                      'pace ${fmtCost(state.perDay)}/day',
                                      style: AppText.data(size: 9.5, color: AppColors.textDim),
                                    ),
                                    Text(
                                      state.series.last.day.substring(5),
                                      style: AppText.data(size: 9, color: AppColors.textDim),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (state.latest != null &&
                          (state.latest!.inputTokens > 0 ||
                              state.latest!.outputTokens > 0)) ...[
                        const SectionHeader(title: 'Token split'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: StatRow(
                              children: [
                                StatCell(label: 'IN', value: fmtTokens(state.latest!.inputTokens)),
                                StatCell(label: 'OUT', value: fmtTokens(state.latest!.outputTokens)),
                                StatCell(label: 'REQUESTS', value: '${state.latest!.requests}'),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (state.history.length > 1) ...[
                        SectionHeader(title: 'Snapshots', trailing: '${state.history.length}'),
                        for (final snapshot in state.history.take(10)) _snapshotTile(snapshot),
                      ],
                      if (state.token != null && state.token!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ApiKeyPanel(apiKey: state.token!),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  List<LimitWindow> _orderedWindows(List<LimitWindow> windows) {
    int rank(LimitKind k) => switch (k) {
      LimitKind.budget => 0,
      LimitKind.burst => 1,
      LimitKind.share => 2,
      LimitKind.extra => 3,
    };
    final sorted = [...windows]..sort((a, b) {
      final c = rank(a.kind).compareTo(rank(b.kind));
      if (c != 0) return c;
      return b.fraction.compareTo(a.fraction);
    });
    return sorted;
  }

  double? _caret(LimitWindow window, double perDay) {
    if (window.cap <= 0 || perDay <= 0 || window.resetAt <= 0) return null;
    final daysToReset =
        (window.resetAt - DateTime.now().millisecondsSinceEpoch) / 86400000;
    if (daysToReset <= 0) return null;
    return (window.used + perDay * daysToReset) / window.cap;
  }

  Widget _header(AccountDetailState state) {
    final account = state.account!;
    final latest = state.latest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProviderAvatar(platform: account.platform, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.label, style: AppText.pageTitle.copyWith(fontSize: 20)),
                      if (account.email.isNotEmpty)
                        Text(account.email, style: AppText.pageSubtitle),
                    ],
                  ),
                ),
                if (latest != null)
                  Text(fmtCost(latest.costUsd), style: AppText.heroNumber()),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'synced ${fmtAgo(account.lastRefreshAt)}',
              style: AppText.data(size: 10, color: AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotTile(SnapshotRow snapshot) {
    final when = DateTime.fromMillisecondsSinceEpoch(snapshot.capturedAt).toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final stamp = '${months[when.month - 1]} ${when.day} · ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(stamp, style: AppText.data(size: 11.5)),
          subtitle: Text(
            '${fmtCost(snapshot.costUsd)} · ${fmtTokens(snapshot.inputTokens + snapshot.outputTokens)} tok · ${snapshot.requests} req',
            style: AppText.data(size: 10, color: AppColors.textDim),
          ),
          children: [
            if (snapshot.windows.isNotEmpty) ...[
              for (final window in snapshot.windows.where((w) => w.cap > 0))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PoolGauge(window: window, compact: true),
                ),
            ],
            if (snapshot.models.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  snapshot.models
                      .map((m) => '${m.model}: ${fmtCost(m.costUsd)}')
                      .join('  ·  '),
                  style: AppText.data(size: 10, color: AppColors.textDim, height: 1.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
