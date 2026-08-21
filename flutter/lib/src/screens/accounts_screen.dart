import 'package:flutter/material.dart';

import '../providers/registry.dart';
import '../state/app_scope.dart';
import '../state/view_models.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'account_detail_screen.dart';
import 'settings_screen.dart';

enum _AccountAction { rename, remove }

class AccountsScreen extends StatelessWidget {
  final VoidCallback onOpenAdd;

  const AccountsScreen({super.key, required this.onOpenAdd});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.accountsVm,
      builder: (context, _) {
        final vm = scope.accountsVm;
        final rows = vm.rows;
        final failing = rows
            .where((r) => r.data.account.syncError.isNotEmpty)
            .length;

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
                    eyebrow: rows.isEmpty
                        ? null
                        : failing > 0
                        ? '$failing NEED ATTENTION'
                        : 'ALL KEYS WORKING',
                    title: 'Accounts',
                    subtitle: rows.isEmpty
                        ? 'Nothing connected yet.'
                        : '${rows.length} connected. Every key is stored in '
                              'this phone\'s keystore and never leaves it.',
                  ),
                  const SizedBox(height: 20),
                  if (vm.error != null) ...[
                    InlineMessage.error(
                      vm.error!,
                      action: TextButton(
                        onPressed: () => vm.load(),
                        child: const Text('RETRY'),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (vm.loading && rows.isEmpty)
                    const Column(
                      children: [
                        SkeletonBar(height: 84),
                        SizedBox(height: 10),
                        SkeletonBar(height: 84),
                      ],
                    )
                  else if (rows.isEmpty && vm.error == null)
                    EmptyState(
                      icon: Icons.link_off_rounded,
                      title: 'No accounts yet',
                      hint:
                          'Add a provider to see what is left in each pool '
                          'and when it refills.',
                      action: FilledButton.icon(
                        onPressed: onOpenAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('ADD AN ACCOUNT'),
                      ),
                    )
                  else
                    for (final row in rows)
                      AccountUsageCard(
                        key: ValueKey(row.data.account.key),
                        account: row.data.account,
                        costUsd: row.data.latest?.costUsd ?? 0,
                        requests: row.data.latest?.requests ?? 0,
                        inputTokens: row.data.latest?.inputTokens ?? 0,
                        outputTokens: row.data.latest?.outputTokens ?? 0,
                        windows: row.data.windows,
                        models: row.data.latest?.models ?? const [],
                        lastRefreshAt: row.data.account.lastRefreshAt,
                        onOpen: () =>
                            _openDetail(context, row.data.account.key),
                        footer: _footer(context, scope, row),
                        banner: row.data.account.syncError.isEmpty
                            ? null
                            : InlineMessage.error(
                                row.data.account.syncError,
                                action: TextButton(
                                  onPressed: () =>
                                      _updateKey(context, scope, row),
                                  child: const Text('UPDATE KEY'),
                                ),
                              ),
                      ),
                  if (rows.isNotEmpty) const SizedBox(height: 2),
                  AddAccountCard(onPressed: onOpenAdd),
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

  void _openDetail(BuildContext context, String key) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountDetailScreen(accountKey: key),
      ),
    );
  }

  Widget _footer(BuildContext context, AppScope scope, AccountRowView row) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          const Divider(height: 1),
          Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    _refreshOne(context, scope, row.data.account.key),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('SYNC'),
              ),
              const Spacer(),
              PopupMenuButton<_AccountAction>(
                tooltip: 'More actions for ${row.data.account.label}',
                icon: const Icon(Icons.more_horiz, size: 19),
                color: AppColors.riser,
                onSelected: (action) => switch (action) {
                  _AccountAction.rename => _rename(context, scope, row),
                  _AccountAction.remove => _removeOne(context, scope, row),
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _AccountAction.rename,
                    child: Text('Rename'),
                  ),
                  PopupMenuItem(
                    value: _AccountAction.remove,
                    child: Text(
                      'Remove',
                      style: AppText.body(size: 13, color: AppColors.hotLit),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refreshOne(
    BuildContext context,
    AppScope scope,
    String key,
  ) async {
    final ok = await scope.accountsVm.refreshOne(key);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync failed. Check the API key and your connection.'),
        ),
      );
    }
  }

  Future<void> _updateKey(
    BuildContext context,
    AppScope scope,
    AccountRowView row,
  ) async {
    final controller = TextEditingController();
    try {
      final token = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Update ${providerName(row.data.account.platform)} key'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'New API key',
              helperText: providerById(row.data.account.platform)?.howToGetToken,
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('SAVE KEY'),
            ),
          ],
        ),
      );
      if (token == null || token.trim().isEmpty) return;
      final ok = await scope.accountsVm.updateToken(
        row.data.account.key,
        token,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Key saved. Account synced.' : 'That key was rejected.',
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _rename(
    BuildContext context,
    AppScope scope,
    AccountRowView row,
  ) async {
    final controller = TextEditingController(text: row.data.account.label);
    try {
      final label = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rename account'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Display name'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('RENAME'),
            ),
          ],
        ),
      );
      if (label == null) return;
      final trimmed = label.trim();
      if (trimmed.isEmpty || trimmed == row.data.account.label) return;
      await scope.accountsVm.rename(row.data.account.key, trimmed);
    } finally {
      controller.dispose();
    }
  }

  void _removeOne(BuildContext context, AppScope scope, AccountRowView row) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove account'),
        content: Text(
          'This deletes ${row.data.account.label}, its saved usage history '
          'and its API key from this device. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('KEEP IT'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await scope.accountsVm.remove(row.data.account.key);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.hotLit),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }
}
