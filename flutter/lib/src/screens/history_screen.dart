import 'package:flutter/material.dart';

import '../db/db.dart';
import '../providers/registry.dart';
import '../state/app_scope.dart';
import '../state/view_models.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_screen.dart';

/// The log. Every snapshot the app has captured, newest first.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _platformFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.historyVm,
      builder: (context, _) {
        final vm = scope.historyVm;
        final present = _platformsPresent(vm.days);
        // A filter for a provider you do not use is just noise.
        final active = present.contains(_platformFilter)
            ? _platformFilter
            : 'all';
        final filtered = _filter(vm.days, active);
        final total = filtered.fold<double>(
          0,
          (sum, day) =>
              sum + day.entries.fold<double>(0, (s, e) => s + e.costUsd),
        );

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.cold,
              backgroundColor: AppColors.deck,
              onRefresh: () async {
                await scope.sync.sync();
                await vm.load();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageTop,
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageBottom,
                ),
                children: [
                  BrandBarWithSync(
                    onOpenSettings: () => _openSettings(context),
                  ),
                  const SizedBox(height: 22),
                  PageHeading(
                    eyebrow: filtered.isEmpty
                        ? null
                        : '${fmtCost(total)} IN VIEW',
                    title: 'History',
                    subtitle:
                        'A snapshot is saved every time an account syncs.',
                  ),
                  const SizedBox(height: 20),
                  _RangeBar(
                    selected: vm.rangeDays,
                    onSelect: (days) => vm.setRange(days),
                  ),
                  if (present.length > 1) ...[
                    const SizedBox(height: 9),
                    _ProviderBar(
                      platforms: present,
                      selected: active,
                      onSelect: (p) => setState(() => _platformFilter = p),
                    ),
                  ],
                  if (vm.error != null) ...[
                    const SizedBox(height: 18),
                    InlineMessage.error(
                      vm.error!,
                      action: TextButton(
                        onPressed: () => vm.load(),
                        child: const Text('RETRY'),
                      ),
                    ),
                  ],
                  if (vm.loading && vm.days.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 26),
                      child: Column(
                        children: [
                          SkeletonBar(height: 60),
                          SizedBox(height: 10),
                          SkeletonBar(height: 60),
                        ],
                      ),
                    )
                  else if (vm.error == null && filtered.isEmpty)
                    EmptyState(
                      icon: Icons.timeline_rounded,
                      title: vm.hasSnapshots
                          ? 'Nothing in this range'
                          : 'No snapshots yet',
                      hint: vm.hasSnapshots
                          ? 'Widen the time range or pick another provider.'
                          : 'Sync an account and the history starts filling '
                                'in from there.',
                    )
                  else
                    for (final day in filtered) ...[
                      SectionHeader(
                        title: _dayLabel(day.day),
                        trailing: fmtCost(
                          day.entries.fold<double>(
                            0,
                            (sum, e) => sum + e.costUsd,
                          ),
                        ),
                      ),
                      ThermalCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < day.entries.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _entryTile(day.entries[i], vm.labels),
                            ],
                          ],
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  List<String> _platformsPresent(List<HistoryDay> days) {
    final seen = <String>{};
    for (final day in days) {
      for (final entry in day.entries) {
        seen.add(entry.platform);
      }
    }
    final sorted = seen.toList()
      ..sort((a, b) => providerName(a).compareTo(providerName(b)));
    return ['all', ...sorted];
  }

  List<HistoryDay> _filter(List<HistoryDay> days, String platform) {
    if (platform == 'all') return days;
    return [
      for (final day in days)
        if (day.entries.any((e) => e.platform == platform))
          HistoryDay(
            day: day.day,
            entries: day.entries
                .where((e) => e.platform == platform)
                .toList(),
          ),
    ];
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
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
    return '${months[day.month - 1]} ${day.day}';
  }

  Widget _entryTile(SnapshotRow entry, Map<String, String> labels) {
    final when = DateTime.fromMillisecondsSinceEpoch(
      entry.capturedAt,
    ).toLocal();
    final stamp =
        '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';
    final pools = entry.windows.where((w) => w.cap > 0).toList();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        showTrailingIcon: pools.isNotEmpty || entry.models.isNotEmpty,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              stamp,
              style: AppText.data(
                size: 11.5,
                weight: FontWeight.w700,
                color: AppColors.haze,
              ),
            ),
          ],
        ),
        title: Text(
          labels[entry.accountKey] ?? entry.accountKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(
            size: 13,
            color: AppColors.beam,
            weight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${fmtTokens(entry.inputTokens + entry.outputTokens)} tok · '
          '${entry.requests} req',
          style: AppText.data(size: 10.5, color: AppColors.haze),
        ),
        trailing: Text(
          fmtCost(entry.costUsd),
          style: AppText.data(size: 13, weight: FontWeight.w700),
        ),
        children: [
          for (final window in pools)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PoolGauge(window: window, compact: true),
            ),
          if (entry.models.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.models
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
    );
  }
}

/// Segmented time range. One control, three mutually exclusive states.
class _RangeBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _RangeBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const options = [(7, '7 DAYS'), (30, '30 DAYS'), (0, 'EVERYTHING')];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.riser,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.rule),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final option in options)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: selected == option.$1,
                  child: InkWell(
                    onTap: () => onSelect(option.$1),
                    borderRadius: BorderRadius.circular(AppRadius.control - 2),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == option.$1
                            ? AppColors.coldSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppRadius.control - 2,
                        ),
                      ),
                      child: Text(
                        option.$2,
                        style: AppText.tag(
                          size: 9.5,
                          color: selected == option.$1
                              ? AppColors.coldLit
                              : AppColors.haze,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Provider filter, only ever showing providers that appear in the log.
class _ProviderBar extends StatelessWidget {
  final List<String> platforms;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ProviderBar({
    required this.platforms,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: platforms.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final platform = platforms[i];
          final on = platform == selected;
          return Semantics(
            button: true,
            selected: on,
            child: InkWell(
              onTap: () => onSelect(platform),
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: on ? AppColors.coldSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(
                    color: on ? AppColors.cold : AppColors.rule,
                  ),
                ),
                child: Text(
                  platform == 'all'
                      ? 'ALL'
                      : providerName(platform).toUpperCase(),
                  style: AppText.tag(
                    size: 9.5,
                    color: on ? AppColors.coldLit : AppColors.haze,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
