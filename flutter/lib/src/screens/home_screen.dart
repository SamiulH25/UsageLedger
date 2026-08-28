import 'dart:async';

import 'package:flutter/material.dart';

import '../data/burn_rate.dart';
import '../data/usage_repository.dart';
import '../providers/registry.dart';
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
  final ScrollController _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _scroll.addListener(() {
      final shouldCollapse = _scroll.offset > 18;
      if (shouldCollapse != _collapsed && mounted) {
        setState(() => _collapsed = shouldCollapse);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
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
        final enableCollapse = state.accounts.isNotEmpty && state.error == null;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: AppMotion.enabled(context)
                      ? const Duration(milliseconds: 220)
                      : Duration.zero,
                  curve: AppMotion.curve,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    enableCollapse && _collapsed ? 8 : 10,
                    AppSpacing.pageHorizontal,
                    enableCollapse && _collapsed ? 8 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: enableCollapse && _collapsed
                        ? AppColors.abyss.withValues(alpha: .92)
                        : AppColors.abyss,
                    border: Border(
                      bottom: BorderSide(
                        color: enableCollapse && _collapsed
                            ? AppColors.rule.withValues(alpha: .6)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: BrandBarWithSync(
                    collapsed: enableCollapse && _collapsed,
                    onOpenSettings: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.cold,
                    backgroundColor: AppColors.deck,
                    onRefresh: () => scope.sync.sync(),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _page(List<Widget> children) => ListView(
    controller: _scroll,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.pageHorizontal,
      4,
      AppSpacing.pageHorizontal,
      AppSpacing.pageBottom,
    ),
    children: children,
  );

  Widget _loading() => _page([
    const SizedBox(height: 10),
    const SkeletonBar(height: 10, widthFactor: .28),
    const SizedBox(height: 16),
    const SkeletonBar(height: 40, widthFactor: .62),
    const SizedBox(height: 26),
    const SkeletonBar(height: 74),
    const SizedBox(height: 10),
    const SkeletonBar(height: 74),
  ]);

  Widget _errorEmpty(BuildContext context, String error) => _page([
    const SizedBox(height: 10),
    InlineMessage.error(
      error,
      action: TextButton(
        onPressed: () => AppScope.of(context).overviewVm.load(),
        child: const Text('RETRY'),
      ),
    ),
  ]);

  Widget _empty(BuildContext context) => _page([
    const SizedBox(height: 10),
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
    final byProvider = _groupByProvider(accounts, state.perDay);

    return _page([
      Text(_todayLabel(), style: AppText.tag()),
      const SizedBox(height: 14),
      _KpiStrip(state: state, runway: runway),
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
      if (byProvider.isNotEmpty) ...[
        const SectionHeader(title: 'Providers', trailing: 'tap to expand'),
        for (final entry in byProvider)
          _ProviderRow(
            platform: entry.$1,
            accounts: entry.$2,
            runway: entry.$3,
            initiallyExpanded: entry == byProvider.first,
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
        if (window.kind == LimitKind.share || window.kind == LimitKind.extra) {
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

  RunwayEntry? _hero(List<RunwayEntry> runway) {
    if (runway.isEmpty) return null;
    return runway.first;
  }

  List<(String, List<AccountOverview>, List<RunwayEntry>)> _groupByProvider(
    List<AccountOverview> accounts,
    double perDay,
  ) {
    final byPlatform = <String, List<AccountOverview>>{};
    for (final a in accounts) {
      byPlatform.putIfAbsent(a.account.platform, () => []).add(a);
    }
    final out = <(String, List<AccountOverview>, List<RunwayEntry>)>[];
    for (final entry in byPlatform.entries) {
      final lanes = <RunwayEntry>[];
      for (final acc in entry.value) {
        for (final w in acc.windows) {
          if (w.cap <= 0 || w.idle) continue;
          if (w.kind == LimitKind.share || w.kind == LimitKind.extra) continue;
          lanes.add(
            RunwayEntry(
              accountLabel: acc.account.label,
              window: w,
              outlook: PoolOutlook.forWindow(w, perDay),
            ),
          );
        }
      }
      lanes.sort((a, b) {
        final aw = a.timeToWall;
        final bw = b.timeToWall;
        if (aw != null && bw != null) return aw.compareTo(bw);
        if (aw != null) return -1;
        if (bw != null) return 1;
        return b.window.fraction.compareTo(a.window.fraction);
      });
      out.add((entry.key, entry.value, lanes));
    }
    out.sort((a, b) {
      double worst(List<RunwayEntry> lanes) => lanes.isEmpty
          ? 0
          : lanes.map((e) => e.window.fraction).reduce((x, y) => x > y ? x : y);
      return worst(b.$3).compareTo(worst(a.$3));
    });
    return out;
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
        const Icon(
          Icons.arrow_outward_rounded,
          size: 14,
          color: AppColors.haze,
        ),
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

class _KpiStrip extends StatelessWidget {
  final OverviewState state;
  final List<RunwayEntry> runway;

  const _KpiStrip({required this.state, required this.runway});

  @override
  Widget build(BuildContext context) {
    final leftTotal = state.accounts
        .expand((a) => a.windows)
        .where(
          (w) =>
              w.cap > 0 &&
              w.kind != LimitKind.share &&
              w.kind != LimitKind.extra,
        )
        .fold(0.0, (s, w) => s + windowRemaining(w));
    final pools = state.accounts
        .expand((a) => a.windows)
        .where(
          (w) =>
              w.cap > 0 &&
              w.kind != LimitKind.share &&
              w.kind != LimitKind.extra,
        )
        .length;
    final hottest = runway.isEmpty ? null : runway.first;
    final burnt = state.spend7 > 0 ? state.spend7 / 7 : state.perDay;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'AMOUNT LEFT',
                value: fmtCost(leftTotal),
                rail: AppColors.cold,
                valueColor: AppColors.coldLit,
                foot: Row(
                  children: [
                    _TagOk(text: '$pools pools healthy'),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '· ${state.accounts.length} providers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.data(size: 10, color: AppColors.haze),
                      ),
                    ),
                  ],
                ),
                railFill: leftTotal > 0 ? 0.68 : 0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'BURN RATE',
                value: burnt > 0 ? '${fmtCost(burnt)}/day' : '—',
                rail: AppColors.warm,
                valueColor: AppColors.warm,
                foot: Row(
                  children: [
                    Icon(Icons.trending_up, size: 10, color: AppColors.warm),
                    const SizedBox(width: 4),
                    Text(
                      '+12% vs 7d',
                      style: AppText.data(
                        size: 10,
                        weight: FontWeight.w600,
                        color: AppColors.warm,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.rule),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('7d', style: AppText.tag(size: 9)),
                    ),
                  ],
                ),
                railFill: 0.74,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'HOTTEST POOL',
                compact: true,
                rail: hottest == null
                    ? AppColors.rule
                    : limitColor(
                        hottest.window.fraction,
                        exceeded: hottest.window.exceeded,
                      ),
                value: hottest == null
                    ? '—'
                    : '${hottest.accountLabel.split(' ').first} · ${fmtCost(windowRemaining(hottest.window))}',
                valueColor: hottest == null
                    ? AppColors.haze
                    : limitTextColor(
                        hottest.window.fraction,
                        exceeded: hottest.window.exceeded,
                      ),
                valueSize: 13,
                foot: Text(
                  hottest == null
                      ? '—'
                      : (hottest.window.exceeded
                            ? 'empty · refills soon'
                            : heatLabel(
                                hottest.window.fraction,
                                exceeded: hottest.window.exceeded,
                              )),
                  style: AppText.data(size: 10, color: AppColors.haze),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'RUNWAY',
                compact: true,
                rail: AppColors.cold,
                value: hottest?.timeToWall == null
                    ? (hottest == null ? '—' : 'on track')
                    : fmtSpan(hottest!.timeToWall!),
                valueColor: AppColors.coldLit,
                valueSize: 13,
                foot: Text(
                  'to refill',
                  style: AppText.data(size: 10, color: AppColors.haze),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'THIS WEEK',
                compact: true,
                rail: AppColors.rule,
                value: fmtCost(state.spend7 > 0 ? state.spend7 / 7 : 0) + '/d',
                valueColor: AppColors.beam,
                valueSize: 13,
                foot: Row(
                  children: [
                    const Icon(
                      Icons.trending_down,
                      size: 10,
                      color: AppColors.coldLit,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '-8% vs last wk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.data(size: 10, color: AppColors.coldLit),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color rail;
  final Color valueColor;
  final Widget foot;
  final double railFill;
  final bool compact;
  final double valueSize;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.rail,
    required this.valueColor,
    required this.foot,
    this.railFill = 0,
    this.compact = false,
    this.valueSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return ThermalCard(
      rail: rail,
      padding: EdgeInsets.fromLTRB(
        12,
        compact ? 10 : 12,
        12,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.tag(size: compact ? 8 : 9)),
          SizedBox(height: compact ? 4 : 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.data(
                size: valueSize,
                weight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          foot,
          if (!compact && railFill > 0) ...[
            const SizedBox(height: 8),
            _MiniRail(fill: railFill, color: rail),
          ],
        ],
      ),
    );
  }
}

class _MiniRail extends StatelessWidget {
  final double fill;
  final Color color;
  const _MiniRail({required this.fill, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.riser,
          borderRadius: BorderRadius.circular(999),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fill.clamp(0, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _TagOk extends StatelessWidget {
  final String text;
  const _TagOk({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.coldSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.coldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.cold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppText.data(
              size: 9,
              weight: FontWeight.w600,
              color: AppColors.coldLit,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatefulWidget {
  final String platform;
  final List<AccountOverview> accounts;
  final List<RunwayEntry> runway;
  final bool initiallyExpanded;

  const _ProviderRow({
    required this.platform,
    required this.accounts,
    required this.runway,
    this.initiallyExpanded = false,
  });

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final leftTotal = widget.accounts
        .expand((a) => a.windows)
        .where(
          (w) =>
              w.cap > 0 &&
              w.kind != LimitKind.share &&
              w.kind != LimitKind.extra,
        )
        .fold(0.0, (s, w) => s + windowRemaining(w));
    final pools = widget.runway.length;
    final hottest = widget.runway.isEmpty ? null : widget.runway.first;
    final rail = hottest == null
        ? AppColors.rule
        : limitColor(
            hottest.window.fraction,
            exceeded: hottest.window.exceeded,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ThermalCard(
        rail: rail,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            initiallyExpanded: _expanded,
            onExpansionChanged: (v) => setState(() => _expanded = v),
            leading: ProviderAvatar(platform: widget.platform, size: 26),
            title: Text(
              providerName(widget.platform),
              style: AppText.data(size: 12, weight: FontWeight.w700),
            ),
            subtitle: Text(
              '$pools pools · ${hottest == null ? 'healthy' : heatLabel(hottest.window.fraction, exceeded: hottest.window.exceeded).toLowerCase()}',
              style: AppText.data(size: 10, color: AppColors.haze),
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmtCost(leftTotal),
                  style: AppText.data(size: 12, weight: FontWeight.w700),
                ),
                Text(
                  '\$${(leftTotal / 100).toStringAsFixed(2)}/d',
                  style: AppText.data(size: 9, color: AppColors.haze),
                ),
              ],
            ),
            children: [
              for (final lane in widget.runway.take(5)) ...[
                const Divider(height: 1),
                RunwayLane(entry: lane),
              ],
              if (widget.runway.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${widget.runway.length - 5} more pools',
                    style: AppText.data(size: 10, color: AppColors.haze),
                  ),
                ),
              for (final acc in widget.accounts) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      ProviderAvatar(platform: acc.account.platform, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          acc.account.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.data(
                            size: 11,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AccountDetailScreen(
                              accountKey: acc.account.key,
                            ),
                          ),
                        ),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
