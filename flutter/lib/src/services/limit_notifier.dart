/// Local notifications when a budget pool runs out.
///
/// Fires at most once per (account, window, reset) — dedupe state lives in
/// the settings store so restarts don't re-notify. Android only; other
/// platforms are a no-op (sideload-only target).
library;

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/usage_repository.dart';
import '../providers/types.dart';
import '../ui/theme.dart';

class LimitNotifier {
  LimitNotifier({UsageRepository? repo})
    : _repo = repo ?? UsageRepository.instance;

  final UsageRepository _repo;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'limit_alerts';
  static const _channelName = 'Limit alerts';
  static const _channelDesc = 'Fires when a budget pool runs out';

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: settings));
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// Check every account's windows after a sync and notify for pools that
  /// just ran out.
  Future<void> evaluate(List<AccountOverview> accounts) async {
    if (!_ready) return;
    for (final account in accounts) {
      for (final w in account.windows) {
        if (w.cap <= 0) continue;
        if (!(w.exceeded || w.fraction >= 1)) continue;
        final key = 'notified:${account.account.key}:${w.id}:${w.resetAt}';
        if (await _repo.setting(key) != null) continue;
        await _repo.setSettingValue(key, '1');
        await _show(w, account.account.label);
      }
    }
  }

  Future<void> _show(LimitWindow w, String accountLabel) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      w.id.hashCode & 0x7fffffff,
      '${w.label} pool is empty',
      '$accountLabel — used \$${w.used.toStringAsFixed(2)} of '
          '\$${w.cap.toStringAsFixed(0)} · ${fmtResetAt(w.resetAt)}',
      details,
    );
  }
}
