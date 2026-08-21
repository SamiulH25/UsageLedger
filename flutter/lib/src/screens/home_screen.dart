import 'dart:async';

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

/// The glance. Answers "how long until I hit a wall?" before anything else.
class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenAdd;

  const HomeScreen({super.key, required this.onOpenAdd});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Countdowns are the whole point of this screen, so keep them honest
    // without waiting for the next sync.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.overviewVm, scope.sync]),
      builder: (context, _) {
        final state = scope.overviewVm.state;
        final Widget body;
        if (state.loading && state.accounts.isEmpty) {
          body = _loading();
        } else if (state.accounts.isEmpty && state.error != null) {
          body = _errorEmpty(context, state.error!);
        } else if (state.accounts.isEmpty) {
          body = _empty(context);
        } else {
          body = _content(context, state, scope.sync.lastError);
        }
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.cold,
              backgroundColor: AppColors.deck,
              onRefresh: () => scope.sync.sync(),
              child: body,
            ),
          ),
        );
      },
    );
  }

  ListView _page(List<Widget> children) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.pageHorizontal,
      AppSpacing.pageTop,
      AppSpacing.pageHorizontal,
      AppSpacing.pageBottom,
    ),
    children: children,
  );

  Widget _brand(BuildContext context) => BrandBarWithSync(
    onOpenSettings: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
  );

  Widget _loading() => _page([
    _brand(context),
    const SizedBox(height: 26),
    const SkeletonBar(height: 10, widthFactor: .28),
    const SizedBox(height: 16),
    const SkeletonBar(height: 40, widthFactor: .62),
    const SizedBox(height: 26),
    const SkeletonBar(height: 74),
    const SizedBox(height: 10),
    const SkeletonBar(height: 74),
  ]);

  Widget _errorEmpty(BuildContext context, String error) => _page([
    _brand(context),
    const SizedBox(height: 24),
    InlineMessage.error(
      error,
      action: TextButton(
        onPressed: () => AppScope.of(context).overviewVm.load(),
        child: const Text('RETRY'),
      ),
    ),
  ]);

  Widget _empty(BuildContext context) => _page([
    _brand(context),
    const SizedBox(height: 26),
    const PageHeading(
      eyebrow: 'NOTHING CONNECTED',
      title: 'Know before you\nhit the wall.',
      subtitle:
          'Connect a provider and UsageLedger tracks what is left in every '
          'pool, and how long your current pace will carry you.',
    ),
    const SizedBox(height: 26),
    FilledButton.icon(
      onPressed: widget.onOpenAdd,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('ADD AN ACCOUNT'),
    ),
  ]);

  Widget _content(
    BuildContext context,
    OverviewState state,
    String? syncError,
  ) {
    final runway = _runway(state);
    final hero = _hero(runway);
    final accounts = state.accounts;

    return _page([
      _brand(context),
      const SizedBox(height: 22),
      Text(_todayLabel(), style: AppText.tag()),
      const SizedBox(height: 14),
      if (hero != null)
        _WallCard(entry: hero, perDay: state.perDay)
      else
        _TotalsCard(state: state),
      if (syncError != null || state.error != null) ...[
        const SizedBox(height: 12),
        InlineMessage.error(
          syncError ?? state.error!,
          action: TextButton(
            onPressed: syncError != null
                ? () => AppScope.of(context).sync.sync()
                : () => AppScope.of(context).overviewVm.load(),
            child: const Text('RETRY'),
          ),
        ),
      ],
      if (!state.delta.isEmpty) ...[
        const SizedBox(height: 10),
        _DeltaStrip(delta: state.delta),
      ],
      if (runway.length >= 2) ...[
        const SectionHeader(title: 'Runway', trailing: 'to each reset'),
        ThermalCard(
          padding: const EdgeInsets.fromLTRB(15, 6, 15, 6),
          child: Column(
            children: [
              for (var i = 0; i < runway.length && i < 5; i++) ...[
                if (i > 0) const Divider(height: 1),
                RunwayLane(entry: runway[i]),
              ],
            ],
          ),
        ),
      ],
      if (state.monthlyBudget > 0) ...[
        const SectionHeader(title: 'Your budget', trailing: 'last 30 days'),
        ThermalCard(
          rail: limitColor(
            state.monthlyBudget > 0 ? state.spend30 / state.monthlyBudget : 0,
          ),
          child: PoolGauge(
            window: LimitWindow(
              id: 'user:month',
              label: 'Self-imposed monthly cap',
              used: state.spend30,
              cap: state.monthlyBudget,
              kind: LimitKind.budget,
            ),
          ),
        ),
      ],
      if (state.spend7 > 0 || state.spend30 > 0) ...[
        const SectionHeader(title: 'Tracked spend'),
        ThermalCard(
          child: Column(
            children: [
              MetricRow(
                metrics: [
                  Metric('7 DAYS', fmtCost(state.spend7)),
                  Metric('30 DAYS', fmtCost(state.spend30)),
                  Metric(
                    'PER DAY',
                    state.perDay > 0 ? fmtCost(state.perDay) : '—',
                  ),
                ],
              ),
              if (state.series.length >= 2) ...[
                const SizedBox(height: 18),
                CostChart(series: state.series),
              ],
            ],
          ),
        ),
      ],
      if (state.topModels.isNotEmpty) ...[
        const SectionHeader(title: 'Top models', trailing: 'all accounts'),
        ThermalCard(
          child: Column(
            children: [
              for (final m in state.topModels) ...[
                if (m != state.topModels.first) const SizedBox(height: 11),
                _ModelCostRow(model: m, maxCost: state.topModels.first.costUsd),
              ],
            ],
          ),
        ),
      ],
      SectionHeader(
        title: 'Accounts',
        trailing: '${accounts.length} connected',
      ),
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
      const SizedBox(height: 2),
      AddAccountCard(onPressed: widget.onOpenAdd),
    ]);
  }

  /// Every capped pool worth projecting, most urgent first.
  List<RunwayEntry> _runway(OverviewState state) {
    final entries = <RunwayEntry>[];
    for (final account in state.accounts) {
      for (final window in account.windows) {
        if (window.cap <= 0 || window.idle) continue;
        if (window.kind == LimitKind.share ||
            window.kind == LimitKind.extra) {
          continue;
        }
        entries.add(
          RunwayEntry(
            accountLabel: account.account.label,
            window: window,
            outlook: PoolOutlook.forWindow(window, state.perDay),
          ),
        );
      }
    }
    entries.sort((a, b) {
      final aWall = a.timeToWall;
      final bWall = b.timeToWall;
      if (aWall != null && bWall != null) return aWall.compareTo(bWall);
      if (aWall != null) return -1;
      if (bWall != null) return 1;
      return b.window.fraction.compareTo(a.window.fraction);
    });
    return entries;
  }

  /// The pool that decides your day: the soonest wall, else the tightest pool.
  RunwayEntry? _hero(List<RunwayEntry> runway) {
    if (runway.isEmpty) return null;
    return runway.first;
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
  const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  return '${weekdays[now.weekday - 1]} ${now.day} ${months[now.month - 1]}'
      '  ·  $hh:$mm';
}

/// The hero. A duration means you are heading for a wall; a dollar figure
/// means nothing is at risk and the number that matters is what is left.
class _WallCard extends StatelessWidget {
  final RunwayEntry entry;
  final double perDay;

  const _WallCard({required this.entry, required this.perDay});

  @override
  Widget build(BuildContext context) {
    final window = entry.window;
    final dry = window.exceeded || window.fraction >= 1;
    final wall = entry.timeToWall;
    final reset = untilReset(window);
    final lit = limitTextColor(window.fraction, exceeded: window.exceeded);
    // Racing a wall is a runway question; otherwise the rail just reports how
    // much is left in the tightest pool.
    final racing = dry || wall != null;
    final color = racing
        ? runwayColor(entry.survivedFraction, dry: dry)
        : limitColor(window.fraction, exceeded: window.exceeded);
    final valueColor = racing
        ? runwayTextColor(entry.survivedFraction, dry: dry)
        : AppColors.beam;

    final String eyebrow;
    final String value;
    if (dry) {
      eyebrow = 'EMPTY · REFILLS IN';
      value = reset == null ? 'unknown' : fmtSpan(reset);
    } else if (wall != null) {
      eyebrow = 'DRY IN';
      value = fmtSpan(wall);
    } else {
      eyebrow = 'TIGHTEST POOL';
      value = fmtCost(windowRemaining(window));
    }

    final safe = entry.outlook.safePerDay;

    return ThermalCard(
      rail: color,
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Readout(
            eyebrow: eyebrow,
            value: value,
            detail: '${entry.accountLabel} · ${window.label}',
            color: valueColor,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          MetricRow(
            metrics: [
              Metric('LEFT', fmtCost(windowRemaining(window)), color: lit),
              Metric('PER DAY', perDay > 0 ? fmtCost(perDay) : '—'),
              Metric('RESET', reset == null ? '—' : fmtSpan(reset)),
            ],
          ),
          if (safe != null && safe > 0 && wall != null) ...[
            const SizedBox(height: 14),
            Text(
              'Spend under ${fmtCost(safe)} a day and this pool lasts to '
              'the reset.',
              style: AppText.body(size: 12, color: AppColors.haze),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fallback hero when no account reports a capped pool.
class _TotalsCard extends StatelessWidget {
  final OverviewState state;

  const _TotalsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final tokens = state.totals.inputTokens + state.totals.outputTokens;
    return ThermalCard(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Readout(
            eyebrow: 'TRACKED SPEND',
            value: fmtCost(state.totals.costUsd),
            detail: 'No provider on this device reports a capped pool.',
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          MetricRow(
            metrics: [
              Metric('TOKENS', fmtTokens(tokens)),
              Metric('REQUESTS', '${state.totals.requests}'),
              Metric(
                'PACE / DAY',
                state.perDay > 0 ? fmtCost(state.perDay) : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the most recent sync actually added.
class _DeltaStrip extends StatelessWidget {
  final UsageDelta delta;

  const _DeltaStrip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (delta.costUsd > 0) fmtCost(delta.costUsd),
      if (delta.tokens > 0) '${fmtTokens(delta.tokens)} tokens',
      if (delta.requests > 0) '${delta.requests} requests',
    ];
    return Row(
      children: [
        const Icon(Icons.arrow_outward_rounded, size: 14, color: AppColors.haze),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Since last sync: ${parts.join(' · ')}',
            style: AppText.data(size: 11, color: AppColors.haze),
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
        const SizedBox(height: 6),
        Meter(fraction: share, color: AppColors.rule, height: 3),
      ],
    );
  }
}
