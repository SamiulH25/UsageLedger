import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/csv_export.dart';
import '../data/key_backup.dart';
import '../services/device_actions.dart';
import '../services/update_checker.dart';
import '../state/app_scope.dart';
import '../state/sync_controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Shown in Settings; bump per release.
const appVersion = '1.0.0';

/// Sync interval, notification, and about settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsKey = 'notificationsEnabled';
  static const _budgetKey = 'userMonthlyBudget';
  bool _notificationsOn = true;
  bool _savingBudget = false;
  String? _budgetError;
  final _budgetCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scope = context.getInheritedWidgetOfExactType<AppScope>()!;
    final stored = await scope.repository.setting(_notificationsKey);
    final budget = await scope.repository.setting(_budgetKey);
    if (!mounted) return;
    setState(() {
      _notificationsOn = stored != '0';
      _budgetCtrl.text = budget ?? '';
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsOn = value);
    final scope = context.getInheritedWidgetOfExactType<AppScope>()!;
    await scope.repository.setSettingValue(
      _notificationsKey,
      value ? '1' : '0',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.sync,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              16,
              AppSpacing.pageHorizontal,
              AppSpacing.pageBottom,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 20),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text('Settings', style: AppText.pageTitle),
                  ),
                ],
              ),
              const SectionHeader(title: 'Sync interval'),
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Foreground refresh while the app is open. '
                        'Android background refresh runs every 15 minutes or more.'
                        '${scope.sync.intervalMinutes == 0 ? ' Auto-sync is off — pull to refresh.' : ''}',
                        style: AppText.data(size: 12, color: AppColors.textDim),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final minutes in SyncController.intervalChoices)
                            ChoiceChip(
                              label: Text(_intervalLabel(minutes)),
                              selected: scope.sync.intervalMinutes == minutes,
                              onSelected: (_) =>
                                  scope.sync.setInterval(minutes),
                              selectedColor: AppColors.accentSoft,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scope.sync.intervalMinutes == minutes
                                    ? AppColors.accent
                                    : AppColors.textDim,
                              ),
                              side: BorderSide(
                                color: scope.sync.intervalMinutes == minutes
                                    ? AppColors.accent
                                    : AppColors.border,
                              ),
                              showCheckmark: false,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SectionHeader(title: 'Reliability'),
              Card(
                color: AppColors.surface,
                child: ListTile(
                  title: const Text(
                    'Battery use',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Allow background refresh to run reliably on Android.',
                    style: AppText.data(size: 11.5, color: AppColors.textDim),
                  ),
                  trailing: const Icon(Icons.battery_saver_outlined, size: 19),
                  onTap: () => _openBatterySettings(context),
                ),
              ),
              const SectionHeader(title: 'Budget'),
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optional monthly envelope on top of provider caps. '
                        'Uses last-30-days spend.',
                        style: AppText.data(size: 12, color: AppColors.textDim),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _budgetCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monthly budget (USD)',
                          hintText: '70',
                        ),
                        onSubmitted: (_) => _saveBudget(context),
                      ),
                      if (_budgetError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _budgetError!,
                          style: TextStyle(
                            color: AppColors.dangerText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _savingBudget
                              ? null
                              : () => _saveBudget(context),
                          child: Text(
                            _savingBudget ? 'Saving…' : 'Save budget',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionHeader(title: 'Data'),
              Card(
                color: AppColors.surface,
                child: ListTile(
                  title: const Text(
                    'Export history (CSV)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Snapshots and per-model usage, shared as a file.',
                    style: AppText.data(size: 11.5, color: AppColors.textDim),
                  ),
                  trailing: const Icon(Icons.ios_share, size: 18),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final repo = context
                          .getInheritedWidgetOfExactType<AppScope>()!
                          .repository;
                      final path = await exportCsv(repo);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Exported to $path')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Export failed: $e')),
                      );
                    }
                  },
                ),
              ),
              Card(
                color: AppColors.surface,
                child: ListTile(
                  title: const Text(
                    'Backup accounts',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'JSON file you keep. Keys optional — that file is a secret.',
                    style: AppText.data(size: 11.5, color: AppColors.textDim),
                  ),
                  trailing: const Icon(Icons.ios_share, size: 18),
                  onTap: () => _backup(context),
                ),
              ),
              Card(
                color: AppColors.surface,
                child: ListTile(
                  title: const Text(
                    'Import backup',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Restore accounts from a UsageLedger JSON file.',
                    style: AppText.data(size: 11.5, color: AppColors.textDim),
                  ),
                  trailing: const Icon(Icons.file_open_outlined, size: 18),
                  onTap: () => _importBackup(context),
                ),
              ),
              const SectionHeader(title: 'Notifications'),
              Card(
                color: AppColors.surface,
                child: SwitchListTile(
                  title: const Text(
                    'Limit alerts',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Warn at 80% and 90%, then when a pool is empty.',
                    style: AppText.data(size: 11.5, color: AppColors.textDim),
                  ),
                  value: _notificationsOn,
                  onChanged: (value) => _setNotifications(value),
                  activeColor: AppColors.accent,
                ),
              ),
              const SectionHeader(title: 'About'),
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('UsageLedger', style: AppText.brand),
                      const SizedBox(height: 4),
                      Text(
                        'Version $appVersion · keys stay on this device',
                        style: AppText.data(
                          size: 11.5,
                          color: AppColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _checkUpdate(context),
                        child: const Text('Check for update'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _intervalLabel(int minutes) {
    if (minutes == 0) return 'Off';
    if (minutes >= 60) return '${minutes ~/ 60}h';
    return '${minutes}m';
  }

  Future<void> _saveBudget(BuildContext context) async {
    final value = _budgetCtrl.text.trim();
    final parsed = value.isEmpty ? null : double.tryParse(value);
    if (value.isNotEmpty &&
        (parsed == null || !parsed.isFinite || parsed <= 0)) {
      setState(
        () => _budgetError = 'Enter an amount above \$0, or clear the field.',
      );
      return;
    }

    setState(() {
      _savingBudget = true;
      _budgetError = null;
    });
    try {
      final scope = context.getInheritedWidgetOfExactType<AppScope>()!;
      await scope.repository.setSettingValue(_budgetKey, value);
      await scope.overviewVm.load();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value.isEmpty ? 'Monthly budget cleared.' : 'Budget saved.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _budgetError = 'Budget could not be saved: $error');
      }
    } finally {
      if (mounted) setState(() => _savingBudget = false);
    }
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final info = await checkForUpdate(appVersion);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            info.newer
                ? 'v${info.latestTag} is out. Open Releases to download.'
                : 'You are on the latest (${info.latestTag}).',
          ),
          action: SnackBarAction(
            label: 'Link',
            onPressed: () {
              Share.share(info.htmlUrl);
            },
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Update check failed: $e')),
      );
    }
  }

  Future<void> _backup(BuildContext context) async {
    final include = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Include API keys?'),
        content: const Text(
          'A backup with keys can restore accounts after reinstall. '
          'Treat that file as a secret.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Accounts only'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Include keys'),
          ),
        ],
      ),
    );
    if (include == null || !context.mounted) return;
    String? passphrase;
    if (include) {
      passphrase = await _askPassphrase(context, optional: true);
      if (passphrase == null || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = context
          .getInheritedWidgetOfExactType<AppScope>()!
          .repository;
      final path = await exportBackup(
        repo,
        includeKeys: include,
        passphrase: passphrase,
      );
      messenger.showSnackBar(SnackBar(content: Text('Backup at $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;
    final file = picked.files.single;
    final scope = AppScope.of(context);
    try {
      final raw = file.bytes != null
          ? utf8.decode(file.bytes!)
          : file.path == null
          ? ''
          : await File(file.path!).readAsString();
      if (raw.isEmpty) {
        throw const FormatException('The selected file is empty');
      }
      String? passphrase;
      if (backupIsEncrypted(raw)) {
        if (!context.mounted) return;
        passphrase = await _askPassphrase(context);
        if (passphrase == null || !context.mounted) return;
      }
      final result = await importBackupPayload(
        scope.repository,
        raw,
        passphrase: passphrase,
      );
      await Future.wait([
        scope.overviewVm.load(),
        scope.accountsVm.load(),
        scope.historyVm.load(),
      ]);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.imported} account${result.imported == 1 ? '' : 's'}'
            '${result.withKeys > 0 ? ' with keys' : ''}'
            '${result.skipped > 0 ? ' · skipped ${result.skipped}' : ''}.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<String?> _askPassphrase(
    BuildContext context, {
    bool optional = false,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(optional ? 'Protect backup' : 'Backup passphrase'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Passphrase',
              hintText: optional ? 'Leave blank for plain JSON' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (optional)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('Plain JSON'),
              ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(ctx, value);
              },
              child: Text(optional ? 'Encrypt' : 'Unlock'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openBatterySettings(BuildContext context) async {
    final opened = await openBatterySettings();
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Android battery settings are unavailable.'),
      ),
    );
  }
}
