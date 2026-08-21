import 'package:flutter/material.dart';

import '../data/burn_rate.dart';
import '../data/usage_repository.dart';
import '../providers/types.dart';
import '../state/app_scope.dart';
import '../state/view_models.dart';
import '../ui/cost_chart.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'account_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenAdd;

  const HomeScreen({super.key, required this.onOpenAdd});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.overviewVm, scope.sync]),
      builder: (context, _) {
        final state = scope.overviewVm.state;
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () => scope.sync.sync(),
              child: state.loading && state.accounts.isEmpty
                  ? _loading()
                  : state.accounts.isEmpty && state.error == null
                  ? _empty(context)
                  : state.accounts.isEmpty
                  ? _errorEmpty(context, state.error!)
                  : _content(context, state, scope.sync.lastError),
            ),
          ),
        );
      },
    );
  }

  Widget _loading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal + 4,
        20,
        AppSpacing.pageHorizontal + 4,
        AppSpacing.pageBottom,
      ),
      children: const [
        _BrandRow(),
        SizedBox(height: 24),
        EmptyState(
          icon: Icons.sync,
          title: 'Loading usage',
          hint: 'Reading saved accounts and latest snapshots.',
        ),
      ],
    );
  }

  Widget _errorEmpty(BuildContext context, String error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal + 4,
        20,
        AppSpacing.pageHorizontal + 4,
        AppSpacing.pageBottom,
      ),
      children: [
        const _BrandRow(),
        const SizedBox(height: 24),
        InlineMessage.error(
          error,
          action: TextButton(
            onPressed: () => AppScope.of(context).overviewVm.load(),
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal + 4,
        20,
        AppSpacing.pageHorizontal + 4,
        AppSpacing.pageBottom,
      ),
      children: [
        const _BrandRow(),
        const SizedBox(height: 24),
        const PageHeading(
          title: 'Keep every account\nin view.',
          subtitle:
              'Connect a provider once, then see spend, limits, and resets in one place.',
        ),
        const SizedBox(height: 24),
        EmptyState(
          icon: Icons.speed_outlined,
          title: 'No accounts yet',
          hint: 'Connect a provider to start tracking usage on this device.',
          action: FilledButton.icon(
            onPressed: onOpenAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add an account'),
          ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    OverviewState state,
    String? syncError,
  ) {
    final tokenCount = state.totals.inputTokens + state.totals.outputTokens;
    final accounts = state.accounts;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        16,
        AppSpacing.pageHorizontal,
        AppSpacing.pageBottom,
      ),
      children: [
        const _BrandRow(),
        const SizedBox(height: 18),
        Text(_todayLabel(), style: AppText.eyebrow),
        const SizedBox(height: 6),
        const PageHeading(
          title: 'Overview',
          subtitle: 'What is left in each pool, and when it resets.',
        ),
        if (syncError != null || state.error != null) ...[
          const SizedBox(height: 14),
          InlineMessage.error(
            syncError ?? state.error!,
            action: TextButton(
              onPressed: syncError != null
                  ? () => AppScope.of(context).sync.sync()
                  : () => AppScope.of(context).overviewVm.load(),
              child: const Text('Retry'),
            ),
          ),
        ],
        if (!state.delta.isEmpty) ...[
          const SizedBox(height: 10),
          _SyncDeltaCard(delta: state.delta),
        ],
        const SizedBox(height: 18),
        if (state.heroWindow != null)
          _HeroWallCard(
            window: state.heroWindow!,
            accountLabel: state.heroAccountLabel ?? '',
            outlook: state.heroOutlook!,
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ALL ACCOUNTS', style: AppText.sectionLabel),
                  const SizedBox(height: 10),
                  Text(
                    fmtCost(state.totals.costUsd),
                    style: AppText.heroNumber(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fmtTokens(tokenCount)} tokens · ${state.totals.requests} requests',
                    style: AppText.data(size: 11, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        _StatStrip(state: state, tokenCount: tokenCount),
        const SizedBox(height: 8),
        _SpendWindows(state: state),
        if (state.monthlyBudget > 0) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: PoolGauge(
                window: LimitWindow(
                  id: 'user:month',
                  label: 'Your monthly budget',
                  used: state.spend30,
                  cap: state.monthlyBudget,
                  kind: LimitKind.budget,
                ),
              ),
            ),
          ),
        ],
        _UrgencyList(accounts: accounts),
        if (state.topModels.isNotEmpty) ...[
          const SectionHeader(title: 'Top models', trailing: 'all accounts'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final m in state.topModels) ...[
                    _ModelCostRow(
                      model: m,
                      maxCost: state.topModels.first.costUsd,
                    ),
                    if (m != state.topModels.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (state.series.length >= 2) ...[
          const SectionHeader(title: 'Tracked spend by day'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: CostChart(series: state.series),
            ),
          ),
        ],
        SectionHeader(title: 'Accounts', trailing: '${accounts.length} active'),
        for (final account in accounts)
          AccountUsageCard(
            key: ValueKey(account.account.key),
            account: account.account,
            costUsd: account.latest?.costUsd ?? 0,
            requests: account.latest?.requests ?? 0,
            inputTokens: account.latest?.inputTokens ?? 0,
            outputTokens: account.latest?.outputTokens ?? 0,
            windows: account.windows,
            models: account.latest?.models ?? const [],
            lastRefreshAt: account.account.lastRefreshAt,
            onOpen: () => _openDetail(context, account.account.key),
          ),
        const SizedBox(height: 4),
        AddAccountCard(onPressed: onOpenAdd),
      ],
    );
  }

  void _openDetail(BuildContext context, String key) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountDetailScreen(accountKey: key),
      ),
    );
  }
}

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
  return '${weekdays[now.weekday].toUpperCase()}, ${months[now.month].toUpperCase()} ${now.day}';
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) =>
      BrandBarWithSync(onOpenSettings: () => _openSettings(context));

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }
}

/// The most urgent pool, framed as an instrument readout.
class _HeroWallCard extends StatelessWidget {
  final LimitWindow window;
  final String accountLabel;
  final PoolOutlook outlook;

  const _HeroWallCard({
    required this.window,
    required this.accountLabel,
    required this.outlook,
  });

  @override
  Widget build(BuildContext context) {
    final f = window.fraction.clamp(0.0, 1.0);
    final color = limitColor(f, exceeded: window.exceeded);
    final urgent = f >= 0.8 || window.exceeded;
    final reset = fmtResetAt(window.resetAt);
    final safe = outlook.safePerDay;
    double? caret;
    if (outlook.perDay > 0 &&
        outlook.daysToReset != null &&
        outlook.daysToReset! > 0 &&
        window.cap > 0) {
      caret =
          (window.used + outlook.perDay * outlook.daysToReset!) / window.cap;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: urgent ? color.withValues(alpha: .55) : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, size: 15, color: color),
                const SizedBox(width: 7),
                Text(
                  'NEXT WALL',
                  style: AppText.sectionLabel.copyWith(color: color),
                ),
                const Spacer(),
                if (reset.isNotEmpty)
                  Text(
                    reset,
                    style: AppText.data(size: 11, color: AppColors.textDim),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              window.cap > 0
                  ? fmtCost(windowRemaining(window))
                  : fmtCost(window.used),
              style: AppText.heroNumber(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              window.cap > 0
                  ? 'LEFT · ${window.label.toUpperCase()} · ${accountLabel.toUpperCase()}'
                  : 'SPENT · ${window.label.toUpperCase()} · ${accountLabel.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.data(
                size: 10,
                color: AppColors.textDim,
                spacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            PoolGauge(window: window, paceCaretFraction: caret),
            if (outlook.perDay > 0 || (safe != null && f >= 0.5)) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (outlook.perDay > 0)
                    'pace ${fmtCost(outlook.perDay)}/day · ${outlook.verdict()}',
                  if (safe != null && safe > 0 && f >= 0.5)
                    '~${fmtCost(safe)}/day to stay under cap',
                ].join(' · '),
                style: AppText.data(size: 10.5, color: AppColors.textDim),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  final OverviewState state;
  final int tokenCount;

  const _StatStrip({required this.state, required this.tokenCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: StatRow(
          children: [
            StatCell(label: 'SPEND', value: fmtCost(state.totals.costUsd)),
            StatCell(
              label: 'PACE / DAY',
              value: state.perDay > 0 ? fmtCost(state.perDay) : '—',
            ),
            StatCell(label: 'TOKENS', value: fmtTokens(tokenCount)),
            StatCell(label: 'REQUESTS', value: '${state.totals.requests}'),
          ],
        ),
      ),
    );
  }
}

/// 7-day / 30-day spend readout from the daily series.
class _SpendWindows extends StatelessWidget {
  final OverviewState state;

  const _SpendWindows({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.spend7 == 0 && state.spend30 == 0) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LAST 7 DAYS', style: AppText.sectionLabel),
                  const SizedBox(height: 4),
                  Text(
                    fmtCost(state.spend7),
                    style: AppText.data(size: 16, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 34, color: AppColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LAST 30 DAYS', style: AppText.sectionLabel),
                    const SizedBox(height: 4),
                    Text(
                      fmtCost(state.spend30),
                      style: AppText.data(size: 16, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncDeltaCard extends StatelessWidget {
  final UsageDelta delta;

  const _SyncDeltaCard({required this.delta});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (delta.costUsd > 0) fmtCost(delta.costUsd),
      if (delta.tokens > 0) '${fmtTokens(delta.tokens)} tokens',
      if (delta.requests > 0) '${delta.requests} requests',
    ];
    return Card(
      color: AppColors.accentSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(
          children: [
            const Icon(Icons.trending_up, size: 17, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'SINCE LAST SYNC\n${parts.join(' · ')}',
                style: AppText.data(
                  size: 11,
                  color: AppColors.accent,
                  weight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hottest capped pools across accounts, remaining-first.
class _UrgencyList extends StatelessWidget {
  final List<AccountOverview> accounts;

  const _UrgencyList({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, LimitWindow window})>[];
    for (final account in accounts) {
      for (final window in account.windows) {
        if (window.cap <= 0) continue;
        if (window.kind == LimitKind.share) continue;
        rows.add((label: account.account.label, window: window));
      }
    }
    rows.sort((a, b) => b.window.fraction.compareTo(a.window.fraction));
    final top = rows.take(4).toList();
    if (top.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Hottest pools', trailing: 'by % used'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${top[i].label} · ${top[i].window.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.data(
                            size: 11.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        fmtLeft(top[i].window),
                        style: AppText.data(
                          size: 11.5,
                          weight: FontWeight.w700,
                          color: limitColor(top[i].window.fraction),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  PoolGauge(window: top[i].window, compact: true),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One row in the cross-account top-models table.
class _ModelCostRow extends StatelessWidget {
  final ModelUsage model;
  final double maxCost;

  const _ModelCostRow({required this.model, required this.maxCost});

  @override
  Widget build(BuildContext context) {
    final share = maxCost > 0 ? (model.costUsd / maxCost).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                model.model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.data(size: 11.5, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              fmtCost(model.costUsd),
              style: AppText.data(size: 11.5, weight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 4,
            backgroundColor: AppColors.border.withValues(alpha: .4),
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
