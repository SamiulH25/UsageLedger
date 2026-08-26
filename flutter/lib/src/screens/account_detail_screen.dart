import 'package:flutter/material.dart';

import '../data/burn_rate.dart';
import '../db/db.dart' show SnapshotRow;
import '../providers/registry.dart';
import '../providers/types.dart';
import '../state/app_scope.dart';
import '../state/view_models.dart';
import '../ui/cost_chart.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Per-account instrument panel: every pool, its runway, models and history.
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
            title: Text(account?.label ?? 'Account', style: AppText.cardTitle),
            actions: [
              if (account != null)
                IconButton(
                  onPressed: () => _refreshAccount(context),
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  tooltip: 'Sync this account',
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: state.loading
              ? _skeleton()
              : account == null
              ? _missingState(context, state.error)
              : RefreshIndicator(
                  color: AppColors.cold,
                  backgroundColor: AppColors.deck,
                  onRefresh: () => _refreshAccount(context),
                  child: _body(state),
                ),
        );
      },
    );
  }

  Widget _skeleton() => const Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.pageHorizontal,
      8,
      AppSpacing.pageHorizontal,
      0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBar(height: 96),
        SizedBox(height: 22),
        SkeletonBar(height: 10, widthFactor: .22),
        SizedBox(height: 14),
        SkeletonBar(height: 64),
      ],
    ),
  );

  Widget _body(AccountDetailState state) {
    final account = state.account!;
    final latest = state.latest;
    final windows = _orderedWindows(latest?.windows ?? const []);
    final runway = [
      for (final window in windows)
        if (window.cap > 0 &&
            window.kind != LimitKind.share &&
            window.kind != LimitKind.extra)
          RunwayEntry(
            accountLabel: account.label,
            window: window,
            outlook: PoolOutlook.forWindow(window, state.perDay),
          ),
    ];
    final budgets =
        windows.where((w) => w.kind == LimitKind.budget).toList()
          ..sort((a, b) => b.fraction.compareTo(a.fraction));
    final shares = windows.where((w) => w.kind == LimitKind.share).toList();
    final bursts =
        windows.where((w) => w.kind == LimitKind.burst && !w.idle).toList()
          ..sort((a, b) => b.fraction.compareTo(a.fraction));
    final extras = windows.where((w) => w.kind == LimitKind.extra).toList();
    final gauges = [...budgets, ...bursts];

    // Remaining across every capped pool — the headline number.
    final leftTotal = [
      for (final w in windows)
        if (w.cap > 0 && w.kind != LimitKind.share && w.kind != LimitKind.extra)
          windowRemaining(w),
    ].fold(0.0, (a, b) => a + b);
    final hottest = gauges.isEmpty
        ? null
        : gauges.reduce((a, b) => a.fraction >= b.fraction ? a : b);
    final rail = account.syncError.isNotEmpty
        ? AppColors.hot
        : hottest == null
        ? AppColors.rule
        : limitColor(hottest.fraction, exceeded: hottest.exceeded);
    final heroColor = account.syncError.isNotEmpty
        ? AppColors.hotLit
        : hottest == null
        ? AppColors.beam
        : limitTextColor(hottest.fraction, exceeded: hottest.exceeded);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        8,
        AppSpacing.pageHorizontal,
        AppSpacing.pageBottom,
      ),
      children: [
        ThermalCard(
          rail: rail,
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProviderAvatar(platform: account.platform, size: 34),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerName(account.platform).toUpperCase(),
                          style: AppText.tag(size: 9.5),
                        ),
                        if (account.email.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            account.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Remaining-first hero: what is left, in the account's own
              // status colour, with spend pushed into the context line.
              Readout(
                eyebrow: 'LEFT ACROSS POOLS',
                value: leftTotal > 0 ? fmtCost(leftTotal) : fmtCost(latest?.costUsd ?? 0),
                detail: [
                  if (latest != null && latest.costUsd > 0)
                    '${fmtCost(latest.costUsd)} tracked spend',
                  if (account.lastRefreshAt > 0)
                    'Synced ${fmtAgo(account.lastRefreshAt)}',
                ].join(' · '),
                color: heroColor,
                size: 38,
              ),
            ],
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          InlineMessage.error(
            state.error!,
            action: TextButton(
              onPressed: () => _refreshAccount(context),
              child: const Text('RETRY'),
            ),
          ),
        ],
        if (account.syncError.isNotEmpty) ...[
          const SizedBox(height: 12),
          InlineMessage.error(account.syncError),
        ],
        if (runway.isNotEmpty) ...[
          const SectionHeader(title: 'Runway', trailing: 'at current pace'),
          ThermalCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 15, 6),
            child: Column(
              children: [
                for (var i = 0; i < runway.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  RunwayLane(entry: runway[i], showAccount: false),
                ],
                const SizedBox(height: 4),
                const RunwayLegend(),
              ],
            ),
          ),
        ],
        if (gauges.isNotEmpty) ...[
          const SectionHeader(title: 'Pools', trailing: 'what is left'),
          ThermalCard(
            child: Column(
              children: [
                for (var i = 0; i < gauges.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  PoolGauge(
                    window: gauges[i],
                    paceCaretFraction: _caret(gauges[i], state.perDay),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (shares.isNotEmpty) ...[
          const SectionHeader(title: 'Included split', trailing: 'auto · api'),
          ThermalCard(
            child: shares.length >= 2
                ? Row(
                    children: [
                      Expanded(
                        child: ShareBar(
                          label: shares[0].label,
                          fraction: shares[0].fraction,
                          exceeded: shares[0].exceeded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ShareBar(
                          label: shares[1].label,
                          fraction: shares[1].fraction,
                          exceeded: shares[1].exceeded,
                        ),
                      ),
                    ],
                  )
                : ShareBar(
                    label: shares.first.label,
                    fraction: shares.first.fraction,
                    exceeded: shares.first.exceeded,
                  ),
          ),
        ],
        for (final extra in extras)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(child: Text('EXTRA USAGE', style: AppText.tag(size: 9.5))),
                Text(
                  fmtCost(extra.used),
                  style: AppText.data(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: AppColors.warm,
                  ),
                ),
              ],
            ),
          ),
        if (state.series.length >= 2) ...[
          const SectionHeader(title: 'Trend', trailing: 'daily spend'),
          ThermalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Sparkline(
                  values: [for (final point in state.series) point.costUsd],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      state.series.first.day.substring(5).replaceAll('-', '.'),
                      style: AppText.data(size: 9.5, color: AppColors.haze),
                    ),
                    const Spacer(),
                    Text(
                      'pace ${fmtCost(state.perDay)}/day',
                      style: AppText.data(size: 10, color: AppColors.haze),
                    ),
                    const Spacer(),
                    Text(
                      state.series.last.day.substring(5).replaceAll('-', '.'),
                      style: AppText.data(size: 9.5, color: AppColors.haze),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (latest != null &&
            (latest.inputTokens > 0 ||
                latest.outputTokens > 0 ||
                latest.requests > 0)) ...[
          const SectionHeader(title: 'Traffic', trailing: 'latest snapshot'),
          ThermalCard(
            child: MetricRow(
              metrics: [
                Metric('TOKENS IN', fmtTokens(latest.inputTokens)),
                Metric('TOKENS OUT', fmtTokens(latest.outputTokens)),
                Metric('REQUESTS', '${latest.requests}'),
              ],
            ),
          ),
        ],
        if (latest != null && latest.models.isNotEmpty) ...[
          const SectionHeader(title: 'Models'),
          ThermalCard(
            child: ModelBreakdownPanel(
              models: latest.models,
              platform: account.platform,
            ),
          ),
        ],
        if (state.history.length > 1) ...[
          SectionHeader(
            title: 'Snapshots',
            trailing: '${state.history.length} saved',
          ),
          for (final snapshot in state.history.take(10))
            _snapshotTile(snapshot),
        ],
        if (state.token != null && state.token!.isNotEmpty) ...[
          const SectionHeader(title: 'API key', trailing: 'on this device'),
          ApiKeyPanel(apiKey: state.token!),
        ],
      ],
    );
  }

  Widget _missingState(BuildContext context, String? error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: EmptyState(
        icon: error == null
            ? Icons.link_off_rounded
            : Icons.priority_high_rounded,
        title: error == null
            ? 'This account was removed'
            : 'Could not load this account',
        hint: error ?? 'Go back to Accounts and pick another one.',
        action: Row(
          children: [
            if (error != null)
              FilledButton(
                onPressed: () => _vm.load(widget.accountKey),
                child: const Text('RETRY'),
              ),
            if (error != null) const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BACK TO ACCOUNTS'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAccount(BuildContext context) async {
    final scope = AppScope.of(context);
    await _vm.refresh();
    await scope.accountsVm.load();
    await scope.overviewVm.load();
  }

  List<LimitWindow> _orderedWindows(List<LimitWindow> windows) {
    int rank(LimitKind k) => switch (k) {
      LimitKind.budget => 0,
      LimitKind.burst => 1,
      LimitKind.share => 2,
      LimitKind.extra => 3,
    };
    return windows.where((window) => !window.idle).toList()
      ..sort((a, b) {
        final c = rank(a.kind).compareTo(rank(b.kind));
        return c != 0 ? c : b.fraction.compareTo(a.fraction);
      });
  }

  double? _caret(LimitWindow window, double perDay) {
    if (window.cap <= 0 || perDay <= 0 || window.resetAt <= 0) return null;
    final daysToReset =
        (window.resetAt - DateTime.now().millisecondsSinceEpoch) / 86400000;
    if (daysToReset <= 0) return null;
    return (window.used + perDay * daysToReset) / window.cap;
  }

  Widget _snapshotTile(SnapshotRow snapshot) {
    final when = DateTime.fromMillisecondsSinceEpoch(
      snapshot.capturedAt,
    ).toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final stamp =
        '${months[when.month - 1]} ${when.day} · '
        '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';

    return ThermalCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(stamp, style: AppText.data(size: 12)),
          subtitle: Text(
            '${fmtCost(snapshot.costUsd)} · '
            '${fmtTokens(snapshot.inputTokens + snapshot.outputTokens)} tok · '
            '${snapshot.requests} req',
            style: AppText.data(size: 10.5, color: AppColors.haze),
          ),
          children: [
            for (final window in snapshot.windows.where((w) => w.cap > 0))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PoolGauge(window: window, compact: true),
              ),
            if (snapshot.models.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  snapshot.models
                      .map((m) => '${m.model} ${fmtCost(m.costUsd)}')
                      .join('   ·   '),
                  style: AppText.data(
                    size: 10.5,
                    color: AppColors.haze,
                    height: 1.7,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
