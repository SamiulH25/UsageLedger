import 'package:flutter/material.dart';

import '../db/db.dart';
import '../providers/types.dart';
import '../services/usage_service.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class AccountsScreen extends StatefulWidget {
  final VoidCallback onOpenAdd;

  const AccountsScreen({super.key, required this.onOpenAdd});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountView {
  final AccountTotalsRow totals;
  final SnapshotRow? snap;
  const _AccountView({required this.totals, this.snap});

  List<LimitWindow> get windows => snap?.windows ?? const [];
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<_AccountView> _accounts = [];
  bool _busy = false;

  Future<void> _load() async {
    final accounts = await accountTotals();
    final views = <_AccountView>[];
    for (final account in accounts) {
      views.add(
        _AccountView(
          totals: account,
          snap: await latestSnapshot(account.account.key),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _accounts = views);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refreshOne(_AccountView view) async {
    setState(() => _busy = true);
    final result = await refreshAccount(view.totals.account);
    if (!result.ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: ${result.error}')),
      );
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  void _removeOne(_AccountView view) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove account'),
        content: Text(
          'Remove ${view.totals.account.label}? Its usage data and stored API key will be deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await removeAccountWithToken(view.totals.account.key);
              await _load();
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              16,
              AppSpacing.pageHorizontal,
              AppSpacing.pageBottom,
            ),
            children: [
              const AppBrandBar(),
              const SizedBox(height: 20),
              PageHeading(
                title: 'Accounts',
                subtitle: _accounts.isEmpty
                    ? 'Connect a provider to begin tracking.'
                    : '${_accounts.length} connected · keys stay on this device',
              ),
              const SizedBox(height: 18),
              if (_accounts.isEmpty)
                EmptyState(
                  icon: Icons.account_circle_outlined,
                  title: 'No accounts yet',
                  hint:
                      'Add Command Code or Cursor to see spend, limits, and reset times here.',
                  action: FilledButton.icon(
                    onPressed: widget.onOpenAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add an account'),
                  ),
                )
              else ...[
                for (final account in _accounts) _accountCard(account),
                const SizedBox(height: 4),
              ],
              AddAccountCard(onPressed: widget.onOpenAdd),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountCard(_AccountView view) {
    final row = view.totals;
    return AccountUsageCard(
      account: row.account,
      costUsd: row.costUsd,
      requests: row.requests,
      inputTokens: row.inputTokens,
      outputTokens: row.outputTokens,
      windows: view.windows,
      lastRefreshAt: row.account.lastRefreshAt,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: _busy ? null : () => _refreshOne(view),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(_busy ? 'Refreshing…' : 'Refresh'),
          ),
          TextButton(
            onPressed: () => _removeOne(view),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
