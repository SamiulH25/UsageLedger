import '../providers/registry.dart';
import 'package:flutter/material.dart';

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
        final rows = scope.accountsVm.rows;
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                await scope.sync.sync();
                await scope.accountsVm.load();
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
                  PageHeading(
                    title: 'Accounts',
                    subtitle: rows.isEmpty
                        ? 'Connect a provider to begin tracking.'
                        : '${rows.length} connected · keys stay on this device',
                  ),
                  const SizedBox(height: 18),
                  if (scope.accountsVm.error != null && rows.isNotEmpty) ...[
                    InlineMessage.error(
                      scope.accountsVm.error!,
                      action: TextButton(
                        onPressed: () => scope.accountsVm.load(),
                        child: const Text('Retry'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (scope.accountsVm.loading && rows.isEmpty)
                    const EmptyState(
                      icon: Icons.sync,
                      title: 'Loading accounts',
                      hint: 'Reading accounts stored on this device.',
                    )
                  else if (scope.accountsVm.error != null && rows.isEmpty)
                    InlineMessage.error(
                      scope.accountsVm.error!,
                      action: TextButton(
                        onPressed: () => scope.accountsVm.load(),
                        child: const Text('Retry'),
                      ),
                    )
                  else if (rows.isEmpty)
                    EmptyState(
                      icon: Icons.account_circle_outlined,
                      title: 'No accounts yet',
                      hint:
                          'Add a provider to see spend, limits, and reset times here.',
                      action: FilledButton.icon(
                        onPressed: onOpenAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add an account'),
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
                                  child: const Text('Update key'),
                                ),
                              ),
                      ),

                  const SizedBox(height: 4),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => _refreshOne(context, scope, row.data.account.key),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Sync'),
        ),
        const Spacer(),
        PopupMenuButton<_AccountAction>(
          tooltip: 'More account actions',
          onSelected: (action) {
            switch (action) {
              case _AccountAction.rename:
                _rename(context, scope, row);
              case _AccountAction.remove:
                _removeOne(context, scope, row);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: _AccountAction.rename, child: Text('Rename')),
            PopupMenuItem(value: _AccountAction.remove, child: Text('Remove')),
          ],
        ),
      ],
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
          content: Text('Sync failed — check the API key and connection.'),
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (token == null || token.trim().isEmpty) return;
    final ok = await scope.accountsVm.updateToken(row.data.account.key, token);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Key updated — account synced.' : 'That key was rejected.',
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    AppScope scope,
    AccountRowView row,
  ) async {
    final controller = TextEditingController(text: row.data.account.label);
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (label == null) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == row.data.account.label) return;
    await scope.accountsVm.rename(row.data.account.key, trimmed);
  }

  void _removeOne(BuildContext context, AppScope scope, AccountRowView row) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove account'),
        content: Text(
          'Remove ${row.data.account.label}? Its usage data and stored API key will be deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await scope.accountsVm.remove(row.data.account.key);
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
}
