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
                  SegmentedControl<int>(
                    options: const [
                      (7, '7 DAYS'),
                      (30, '30 DAYS'),
                      (0, 'EVERYTHING'),
                    ],
                    selected: vm.rangeDays,
                    onSelect: (days) => vm.setRange(days),
                  ),
                  if (present.length > 1) ...[
                    const SizedBox(height: 9),
                    FilterPills<String>(
                      options: present,
                      selected: active,
                      onSelect: (p) => setState(() => _platformFilter = p),
                      label: (p) =>
                          p == 'all' ? 'ALL' : providerName(p).toUpperCase(),
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
                      _HistoryDayHeader(
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
                              _entryTile(context, day.entries[i], vm.labels),
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
            entries: day.entries.where((e) => e.platform == platform).toList(),
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
}

class _HistoryDayHeader extends StatelessWidget {
  final String title;
  final String trailing;
  const _HistoryDayHeader({required this.title, required this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: AppText.tag(color: AppColors.beam, size: 10.5),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(height: 1)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.riser,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.rule),
            ),
            child: Text(
              trailing,
              style: AppText.data(size: 10, color: AppColors.haze),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _entryTile(
  BuildContext context,
  SnapshotRow entry,
  Map<String, String> labels,
) {
  final when = DateTime.fromMillisecondsSinceEpoch(entry.capturedAt).toLocal();
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
