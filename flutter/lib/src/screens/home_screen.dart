import 'package:flutter/material.dart';

import '../data/burn_rate.dart';
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
      listenable: scope.overviewVm,
      builder: (context, _) {
        final state = scope.overviewVm.state;
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () => scope.sync.sync(),
              child: state.accounts.isEmpty && !state.loading
                  ? _empty(context)
                  : _content(context, state),
            ),
          ),
        );
      },
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
          hint:
              'Add Command Code or Cursor to start tracking usage on this device.',
          action: FilledButton.icon(
            onPressed: onOpenAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add an account'),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, OverviewState state) {
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
          subtitle: 'Pull down to sync usage from every connected account.',
        ),
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
    final urgent = f >= 0.7 || window.exceeded;

    // Caret: where the level lands at reset if the pace holds.
    double? caret;
    if (outlook.perDay > 0 &&
        outlook.daysToReset != null &&
        outlook.daysToReset! > 0) {
      caret =
          ((window.used + outlook.perDay * outlook.daysToReset!) / window.cap);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
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
                Text(
                  fmtCost(window.used),
                  style: AppText.data(
                    size: 13,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  ' / ${fmtCost(window.cap)}',
                  style: AppText.data(size: 12, color: AppColors.textDim),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(fmtPct(f), style: AppText.heroNumber(color: color)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      window.label.toUpperCase(),
                      accountLabel.toUpperCase(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.data(
                      size: 10,
                      color: AppColors.textDim,
                      spacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PoolGauge(window: window, paceCaretFraction: caret),
            if (outlook.perDay > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.trending_up, size: 13, color: AppColors.textDim),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'pace ${fmtCost(outlook.perDay)}/day · ${outlook.verdict()}',
                      style: AppText.data(size: 10.5, color: AppColors.textDim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
