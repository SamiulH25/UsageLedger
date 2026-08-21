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

/// Sync, alerts, budget, backup and about.
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
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: 'Back',
          ),
          title: const Text('Settings'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            4,
            AppSpacing.pageHorizontal,
            AppSpacing.pageBottom,
          ),
          children: [
            const SectionHeader(title: 'Refresh', trailing: 'while open'),
            ThermalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scope.sync.intervalMinutes == 0
                        ? 'Auto-refresh is off. Pull down on any tab to sync '
                              'by hand.'
                        : 'How often UsageLedger re-checks each provider. '
                              'Android runs background refreshes no more than '
                              'once every 15 minutes.',
                    style: AppText.body(size: 12.5),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final minutes in SyncController.intervalChoices)
                        _Pill(
                          label: _intervalLabel(minutes),
                          selected: scope.sync.intervalMinutes == minutes,
                          onTap: () => scope.sync.setInterval(minutes),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Alerts'),
            ThermalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Warn me before a pool empties'),
                    subtitle: const Text(
                      'A notification at 80% and 90%, then when it is gone.',
                    ),
                    value: _notificationsOn,
                    onChanged: _setNotifications,
                    contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                  ),
                  const Divider(height: 1),
                  _SettingTile(
                    title: 'Battery permissions',
                    subtitle:
                        'Android stops background refresh unless UsageLedger '
                        'is exempt from battery optimisation.',
                    icon: Icons.battery_saver_outlined,
                    onTap: () => _openBatterySettings(context),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Your budget', trailing: 'optional'),
            ThermalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A cap you set for yourself, on top of whatever the '
                    'providers allow. Measured against the last 30 days.',
                    style: AppText.body(size: 12.5),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _budgetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monthly budget (USD)',
                      hintText: '70',
                      errorText: _budgetError,
                    ),
                    onSubmitted: (_) => _saveBudget(context),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _savingBudget
                          ? null
                          : () => _saveBudget(context),
                      child: Text(_savingBudget ? 'SAVING…' : 'SAVE BUDGET'),
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Your data', trailing: 'stays local'),
            ThermalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingTile(
                    title: 'Export history',
                    subtitle:
                        'Every snapshot and per-model figure as a CSV file.',
                    icon: Icons.ios_share_rounded,
                    onTap: () => _exportCsv(context),
                  ),
                  const Divider(height: 1),
                  _SettingTile(
                    title: 'Back up accounts',
                    subtitle:
                        'A file you keep. Include your keys and it can '
                        'restore everything after a wipe.',
                    icon: Icons.lock_outline_rounded,
                    onTap: () => _backup(context),
                  ),
                  const Divider(height: 1),
                  _SettingTile(
                    title: 'Restore from backup',
                    subtitle: 'Read accounts back out of a UsageLedger file.',
                    icon: Icons.file_open_outlined,
                    onTap: () => _importBackup(context),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'About'),
            ThermalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppBrandBar(),
                  const SizedBox(height: 10),
                  Text(
                    'Version $appVersion. Every API key lives in this phone\'s '
                    'keystore. Nothing is uploaded anywhere, by anyone.',
                    style: AppText.body(size: 12.5),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () => _checkUpdate(context),
                      child: const Text('CHECK FOR UPDATE'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _intervalLabel(int minutes) {
    if (minutes == 0) return 'OFF';
    if (minutes >= 60) return '${minutes ~/ 60}H';
    return '${minutes}M';
  }

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.getInheritedWidgetOfExactType<AppScope>()!.repository;
    try {
      final path = await exportCsv(repo);
      messenger.showSnackBar(SnackBar(content: Text('Exported to $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
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
                ? 'v${info.latestTag} is out. Open Releases to download it.'
                : 'You are on the latest release (${info.latestTag}).',
          ),
          action: SnackBarAction(
            label: 'LINK',
            onPressed: () => Share.share(info.htmlUrl),
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
        title: const Text('Include your API keys?'),
        content: const Text(
          'With keys, this file restores every account after a reinstall — '
          'and anyone who opens it can use them. Without keys it restores the '
          'account list only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ACCOUNTS ONLY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('INCLUDE KEYS'),
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
      messenger.showSnackBar(SnackBar(content: Text('Backup saved to $path')));
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
            'Restored ${result.imported} '
            'account${result.imported == 1 ? '' : 's'}'
            '${result.withKeys > 0 ? ' with keys' : ''}'
            '${result.skipped > 0 ? ' · skipped ${result.skipped}' : ''}.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
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
          title: Text(optional ? 'Lock this backup' : 'Backup passphrase'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Passphrase',
              helperText: optional
                  ? 'Lose this and the backup cannot be opened again.'
                  : 'The passphrase used when this backup was made.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            if (optional)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('SKIP'),
              ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(ctx, value);
              },
              child: Text(optional ? 'ENCRYPT' : 'UNLOCK'),
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

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(icon, size: 18, color: AppColors.haze),
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      onTap: onTap,
    );
  }
}

/// Small selectable pill used for the refresh interval.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 42),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.coldSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? AppColors.cold : AppColors.rule,
            ),
          ),
          child: Text(
            label,
            style: AppText.tag(
              size: 10.5,
              color: selected ? AppColors.coldLit : AppColors.haze,
            ),
          ),
        ),
      ),
    );
  }
}
