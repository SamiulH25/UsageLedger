import 'package:flutter/material.dart';

import '../db/db.dart';
import '../providers/registry.dart';
import '../services/usage_service.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class AccountsScreen extends StatefulWidget {
  final VoidCallback onOpenAdd;
  const AccountsScreen({super.key, required this.onOpenAdd});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<AccountTotalsRow> _accounts = [];
  bool _busy = false;

  Future<void> _load() async {
    final a = await accountTotals();
    if (!mounted) return;
    setState(() => _accounts = a);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refreshOne(AccountTotalsRow row) async {
    setState(() => _busy = true);
    final res = await refreshAccount(row.account);
    if (!res.ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh failed: ${res.error}')));
    }
    await _load();
    setState(() => _busy = false);
  }

  void _removeOne(AccountTotalsRow row) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove account'),
        content: Text('Remove ${row.account.label}? Its data and stored token will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await removeAccountWithToken(row.account.key);
              await _load();
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: widget.onOpenAdd, child: const Text('+ Add')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _accounts.isEmpty
            ? ListView(children: [
                const SizedBox(height: 120),
                const EmptyState(
                  icon: '👤',
                  title: 'No accounts',
                  hint: 'Add a Command Code or Cursor account to start tracking usage.',
                ),
              ])
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [for (final row in _accounts) _accountCard(row)],
              ),
      ),
    );
  }

  Widget _accountCard(AccountTotalsRow row) {
    final a = row.account;
    final color = hexColor(providerColor(a.platform));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(providerIcon(a.platform), style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                  Text('${providerName(a.platform)}${a.email.isNotEmpty ? ' · ${a.email}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            StatRow(children: [
              StatCard(label: 'Cost', value: fmtCost(row.costUsd), valueColor: AppColors.accent),
              StatCard(label: 'Tokens', value: fmtTokens(row.inputTokens + row.outputTokens)),
              StatCard(label: 'Requests', value: '${row.requests}'),
            ]),
            if (row.inputTokens + row.outputTokens > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${fmtTokens(row.inputTokens)} in · ${fmtTokens(row.outputTokens)} out',
                  style: const TextStyle(fontSize: 11, color: AppColors.textDim),
                ),
              ),
            const SizedBox(height: 4),
            Row(children: [
              TextButton(
                onPressed: _busy ? null : () => _refreshOne(row),
                child: Text(_busy ? 'Refreshing…' : 'Refresh', style: const TextStyle(color: AppColors.accentBlue)),
              ),
              TextButton(
                onPressed: () => _removeOne(row),
                child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
