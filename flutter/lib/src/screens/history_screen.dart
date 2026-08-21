import 'package:flutter/material.dart';

import '../db/db.dart';
import '../providers/registry.dart';
import '../state/app_scope.dart';
import '../state/view_models.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_screen.dart';

void _openSettings(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
}

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
        final days = vm.days;
        final filtered = _platformFilter == 'all'
            ? days
            : [
                for (final day in days)
                  HistoryDay(
                    day: day.day,
                    entries: day.entries
                        .where((e) => e.platform == _platformFilter)
                        .toList(),
                  ),
              ].where((d) => d.entries.isNotEmpty).toList();

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                await scope.sync.sync();
                await vm.load();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  16,
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageBottom,
                ),
                children: [
                  BrandBarWithSync(
                    onOpenSettings: () => _openSettings(context),
                  ),
                  const SizedBox(height: 20),
                  const PageHeading(
                    title: 'History',
                    subtitle:
                        'Every snapshot captured when your accounts sync.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in const [
                        ('all', 'All'),
                        ('commandcode', 'Command Code'),
                        ('cursor', 'Cursor'),
                      ])
                        ChoiceChip(
                          label: Text(option.$2),
                          selected: _platformFilter == option.$1,
                          onSelected: (_) =>
                              setState(() => _platformFilter = option.$1),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontFamily: monoFamily,
                            fontWeight: FontWeight.w500,
                            color: _platformFilter == option.$1
                                ? AppColors.bg
                                : AppColors.textDim,
                          ),
                          selectedColor: AppColors.accent,
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: _platformFilter == option.$1
                                ? AppColors.accent
                                : AppColors.border,
                          ),
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (vm.loading || filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: EmptyState(
                        icon: Icons.history,
                        title: vm.loading ? 'Loading…' : 'No snapshots yet',
                        hint: vm.loading
                            ? ''
                            : 'Sync an account to start building your usage history.',
                      ),
                    )
                  else
                    for (final day in filtered) ...[
                      SectionHeader(
                        title: _dayLabel(day.day),
                        trailing:
                            '${day.entries.length} snapshot${day.entries.length == 1 ? '' : 's'}',
                      ),
                      for (final entry in day.entries)
                        _entryCard(entry, vm.labels),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
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
    return '${months[day.month - 1]} ${day.day}'.toUpperCase();
  }

  Widget _entryCard(SnapshotRow entry, Map<String, String> labels) {
    final when = DateTime.fromMillisecondsSinceEpoch(
      entry.capturedAt,
    ).toLocal();
    final stamp =
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: ProviderAvatar(platform: entry.platform, size: 30),
          title: Text(
            labels[entry.accountKey] ?? entry.accountKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: displayFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '$stamp · ${fmtTokens(entry.inputTokens + entry.outputTokens)} tok · ${entry.requests} req',
            style: AppText.data(size: 10, color: AppColors.textDim),
          ),
          trailing: Text(
            fmtCost(entry.costUsd),
            style: AppText.data(size: 13, weight: FontWeight.w700),
          ),
          children: [
            if (entry.windows.isNotEmpty)
              for (final window in entry.windows.where((w) => w.cap > 0))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PoolGauge(window: window, compact: true),
                ),
            if (entry.models.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  entry.models
                      .map((m) => '${m.model}: ${fmtCost(m.costUsd)}')
                      .join('  ·  '),
                  style: AppText.data(
                    size: 10,
                    color: AppColors.textDim,
                    height: 1.6,
                  ),
                ),
              ),
            if (entry.windows.isEmpty && entry.models.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  providerName(entry.platform),
                  style: AppText.data(size: 10, color: AppColors.textDim),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
