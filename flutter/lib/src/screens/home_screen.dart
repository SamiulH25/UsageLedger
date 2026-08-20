import 'package:flutter/material.dart';

import '../db/db.dart';
import '../providers/registry.dart';
import '../providers/types.dart';
import '../services/usage_service.dart';
import '../ui/cost_chart.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenAdd;
  const HomeScreen({super.key, required this.onOpenAdd});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasAccounts = false;
  String? _error;
  ({double costUsd, int requests, int inputTokens, int outputTokens}) _agg =
      (costUsd: 0, requests: 0, inputTokens: 0, outputTokens: 0);
  List<({String day, double costUsd})> _series = [];
  List<({String platform, double cost})> _perProvider = [];
  List<({String account, LimitWindow w})> _windows = [];
  List<({String account, ModelUsage m})> _models = [];

  Future<void> _load() async {
    final agg = await aggregated();
    final series = await snapshotSeries();
    final accts = await listAccounts();
    final totals = await accountTotals();

    final byPlatform = <String, double>{};
    for (final t in totals) {
      byPlatform[t.account.platform] = (byPlatform[t.account.platform] ?? 0) + t.costUsd;
    }

    final ws = <({String account, LimitWindow w})>[];
    final ms = <({String account, ModelUsage m})>[];
    for (final a in accts) {
      final snap = await latestSnapshot(a.key);
      if (snap != null) {
        for (final w in snap.windows) {
          ws.add((account: a.label, w: w));
        }
        for (final m in snap.models) {
          ms.add((account: a.label, m: m));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _agg = agg;
      _series = series;
      _hasAccounts = accts.isNotEmpty;
      _perProvider = byPlatform.entries.map((e) => (platform: e.key, cost: e.value)).toList();
      _windows = ws;
      _models = ms;
      _error = null;
    });
  }

  Future<void> _refresh() async {
    final res = await refreshAll();
    if (res.failed.isNotEmpty) {
      setState(() => _error = 'Sync issue: ${res.failed.first.error}');
    }
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: widget.onOpenAdd, child: const Text('+ Add')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _hasAccounts ? _content() : ListView(children: [
          const SizedBox(height: 120),
          const EmptyState(
            icon: '🔑',
            title: 'Add an account to start',
            hint: 'Paste your Command Code or Cursor token, and this app pulls your usage directly from the platform APIs.',
          ),
        ]),
      ),
    );
  }

  Widget _content() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow(children: [
                  StatCard(label: 'Cost', value: fmtCost(_agg.costUsd), valueColor: AppColors.accent),
                  StatCard(label: 'Tokens', value: fmtTokens(_agg.inputTokens + _agg.outputTokens)),
                  StatCard(label: 'Requests', value: '${_agg.requests}'),
                ]),
                const SizedBox(height: 12),
                for (final p in _perProvider)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: hexColor(providerColor(p.platform)), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(providerName(p.platform), style: const TextStyle(color: AppColors.text))),
                      Text(fmtCost(p.cost), style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
        if (_series.length >= 2) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cost over time',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 12),
                  CostChart(series: _series),
                ],
              ),
            ),
          ),
        ],
        if (_models.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top models',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 12),
                  for (final e in _models.take(6)) ...[
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.m.model,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.text, fontSize: 13)),
                          Text(
                            '${e.account} · ${fmtTokens(e.m.inputTokens + e.m.outputTokens)} tok · '
                            '${fmtTokens(e.m.cacheReadTokens)} cache',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: AppColors.textDim),
                          ),
                        ]),
                      ),
                      Text(fmtCost(e.m.costUsd),
                          style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (_windows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plan limits',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 12),
                  for (final e in _windows) ...[
                    Row(children: [
                      Expanded(
                        child: Text('${e.account} · ${e.w.label}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.text, fontSize: 13)),
                      ),
                      Text('${fmtCost(e.w.used)} / ${fmtCost(e.w.cap)}',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                    ]),
                    const SizedBox(height: 4),
                    LimitBar(fraction: e.w.fraction),
                    if (e.w.resetAt > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Resets ${DateTime.fromMillisecondsSinceEpoch(e.w.resetAt).toLocal().toString().substring(0, 16)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textDim),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Center(
          child: Text('Pull to refresh', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
        ),
      ],
    );
  }
}
