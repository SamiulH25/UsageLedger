import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/sync_controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Shown in Settings; bump per release.
const appVersion = '0.4.0';

/// Sync interval, notification, and about settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsKey = 'notificationsEnabled';
  bool _notificationsOn = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    // Non-dependent lookup: safe inside initState (unlike AppScope.of).
    final scope = context.getInheritedWidgetOfExactType<AppScope>()!;
    final stored = await scope.repository.setting(_notificationsKey);
    if (!mounted) return;
    setState(() => _notificationsOn = stored != '0');
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
                        'How often accounts refresh while the app is open.'
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
              const SectionHeader(title: 'Notifications'),
              Card(
                color: AppColors.surface,
                child: SwitchListTile(
                  title: const Text(
                    'Limit alerts',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Notify once when a budget pool runs out.',
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
}
