import 'package:flutter/material.dart';

import '../db/db.dart';
import '../providers/registry.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryEntry {
  final String day;
  final String accountLabel;
  final String platform;
  final double cost;
  final int requests;
  final int tokens;
  final String limits;

  _HistoryEntry({
    required this.day,
    required this.accountLabel,
    required this.platform,
    required this.cost,
    required this.requests,
    required this.tokens,
    required this.limits,
  });
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<_HistoryEntry> _entries = [];
  bool _showLimits = false;

  Future<void> _load() async {
    final accounts = await listAccounts();
    final entries = <_HistoryEntry>[];
    for (final account in accounts) {
      final snapshot = await latestSnapshot(account.key);
      if (snapshot == null) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(
        snapshot.capturedAt,
      ).toLocal();
      final dayLabel = '${_wd(date.weekday)} ${_mo(date.month)} ${date.day}';
      entries.add(
        _HistoryEntry(
          day: dayLabel,
          accountLabel: account.label,
          platform: account.platform,
          cost: snapshot.costUsd,
          requests: snapshot.requests,
          tokens: snapshot.inputTokens + snapshot.outputTokens,
          limits: snapshot.windows
              .map((w) => '${w.label}: ${fmtCost(w.used)} / ${fmtCost(w.cap)}')
              .join(' · '),
        ),
      );
    }
    entries.sort((a, b) => b.day.compareTo(a.day));
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  String _wd(int weekday) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday];
  String _mo(int month) => const [
    '',
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
  ][month];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<_HistoryEntry>>{};
    for (final entry in _entries) {
      byDay.putIfAbsent(entry.day, () => []).add(entry);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 34),
            children: [
              const Text(
                'UsageLedger',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.5,
                    ),
                  ),
                  FilterChip(
                    selected: _showLimits,
                    label: Text(_showLimits ? 'Limits on' : 'Show limits'),
                    onSelected: (value) => setState(() => _showLimits = value),
                    selectedColor: AppColors.accentSoft,
                    checkmarkColor: AppColors.accent,
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      color: AppColors.accent,
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Snapshots captured when your accounts refresh.',
                style: TextStyle(color: AppColors.textDim, fontSize: 12),
              ),
              const SizedBox(height: 15),
              if (_entries.isEmpty)
                const EmptyState(
                  icon: '◷',
                  title: 'No snapshots yet',
                  hint:
                      'Refresh an account to start building your usage history.',
                )
              else
                for (final day in days) ...[
                  SectionHeader(
                    title: day,
                    trailing:
                        '${byDay[day]!.length} account${byDay[day]!.length == 1 ? '' : 's'}',
                  ),
                  for (final entry in byDay[day]!) _entryCard(entry),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryCard(_HistoryEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProviderAvatar(platform: entry.platform, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.accountLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  fmtCost(entry.cost),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              '${providerName(entry.platform)} · ${fmtTokens(entry.tokens)} tokens · ${entry.requests} requests',
              style: const TextStyle(fontSize: 10, color: AppColors.textDim),
            ),
            if (_showLimits && entry.limits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  entry.limits,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textDim,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
