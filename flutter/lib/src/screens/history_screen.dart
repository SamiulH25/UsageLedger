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
  final String limits; // one-line summary
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
    for (final a in accounts) {
      final snap = await latestSnapshot(a.key);
      if (snap == null) continue;
      final day = DateTime.fromMillisecondsSinceEpoch(snap.capturedAt).toLocal();
      final dayLabel = '${_wd(day.weekday)} ${_mo(day.month)} ${day.day}';
      final limits = snap.windows
          .map((w) => '${w.label}: ${fmtCost(w.used)} / ${fmtCost(w.cap)}')
          .join(' · ');
      entries.add(_HistoryEntry(
        day: dayLabel,
        accountLabel: a.label,
        platform: a.platform,
        cost: snap.costUsd,
        requests: snap.requests,
        tokens: snap.inputTokens + snap.outputTokens,
        limits: limits,
      ));
    }
    entries.sort((x, y) => y.day.compareTo(x.day));
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  String _wd(int w) => const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w];
  String _mo(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<_HistoryEntry>>{};
    for (final e in _entries) {
      byDay.putIfAbsent(e.day, () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showLimits = !_showLimits),
            child: Text(_showLimits ? 'Hide limits' : 'Show limits',
                style: const TextStyle(color: AppColors.accentBlue)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _entries.isEmpty
            ? ListView(children: [
                const SizedBox(height: 120),
                const EmptyState(
                  icon: '🕘',
                  title: 'No snapshots yet',
                  hint: 'Snapshots are recorded each time you refresh, building a history over time.',
                ),
              ])
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final day in days) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Text(day,
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                    ),
                    for (final e in byDay[day]!) _entryCard(e),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _entryCard(_HistoryEntry e) {
    final color = hexColor(providerColor(e.platform));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(e.accountLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text)),
            ),
            Text(fmtCost(e.cost), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text('${providerName(e.platform)} · ${fmtTokens(e.tokens)} tok · ${e.requests} req',
              style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
          if (_showLimits && e.limits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(e.limits, style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
            ),
        ]),
      ),
    );
  }
}
