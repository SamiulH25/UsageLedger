/// Local notifications when a budget pool runs out.
///
/// Fires tiered alerts at 80%, 90%, and 100% — at most once per
/// (account, window, reset, tier). Dedupe state lives in the settings store
/// so restarts don't re-notify. Android only; other platforms are a no-op
/// (sideload-only target).
library;

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/usage_repository.dart';
import '../providers/types.dart';
import '../ui/theme.dart';

/// Which alert tiers apply to [w] on a single evaluate pass (highest only).
List<int> alertTiersFor(LimitWindow w) {
  if (w.exceeded || w.fraction >= 1) return [100];
  if (w.fraction >= 0.9) return [90];
  if (w.fraction >= 0.8) return [80];
  return [];
}

class LimitNotifier {
  LimitNotifier({UsageRepository? repo})
    : _repo = repo ?? UsageRepository.instance;

  final UsageRepository _repo;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _enabledKey = 'notificationsEnabled';

  static const _limitChannelId = 'limit_alerts';
  static const _limitChannelName = 'Limit alerts';
  static const _limitChannelDesc = 'Fires when a budget pool runs out';

  static const _warningChannelId = 'usage_warnings';
  static const _warningChannelName = 'Usage warnings';
  static const _warningChannelDesc =
      'Alerts when a budget pool reaches 80% or 90%';

  static const _syncHealthChannelId = 'sync_health';
  static const _syncHealthChannelName = 'Sync health';
  static const _syncHealthChannelDesc = 'Alerts when an account sync fails';

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    if (_ready) return;
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: settings));
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _warningChannelId,
        _warningChannelName,
        description: _warningChannelDesc,
        importance: Importance.defaultImportance,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _limitChannelId,
        _limitChannelName,
        description: _limitChannelDesc,
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _syncHealthChannelId,
        _syncHealthChannelName,
        description: _syncHealthChannelDesc,
        importance: Importance.defaultImportance,
      ),
    );
    _ready = true;
  }

  /// Check every account's windows after a sync and notify for pools that
  /// crossed a tier threshold.
  Future<void> evaluate(List<AccountOverview> accounts) async {
    if (!_ready) return;
    if (await _repo.setting(_enabledKey) == '0') return;
    for (final overview in accounts) {
      final account = overview.account;
      if (account.syncError.isNotEmpty && account.lastRefreshAt != 0) {
        final syncKey = 'notified-sync:${account.key}:${account.lastRefreshAt}';
        if (await _repo.setting(syncKey) == null) {
          await _repo.setSettingValue(syncKey, '1');
          await _showSyncFailed(account.key, account.label);
        }
      }
      for (final w in overview.windows) {
        if (w.cap <= 0) continue;
        for (final tier in alertTiersFor(w)) {
          final key = 'notified:${account.key}:${w.id}:${w.resetAt}:$tier';
          if (await _repo.setting(key) != null) continue;
          await _repo.setSettingValue(key, '1');
          await _showWindow(w, account.label, tier);
        }
      }
    }
  }

  Future<void> _showWindow(LimitWindow w, String accountLabel, int tier) async {
    final notificationId = (w.id.hashCode ^ tier) & 0x7fffffff;
    if (tier == 100) {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _limitChannelId,
          _limitChannelName,
          channelDescription: _limitChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.show(
        notificationId,
        '${w.label} pool is empty',
        '$accountLabel — used \$${w.used.toStringAsFixed(2)} of '
            '\$${w.cap.toStringAsFixed(0)} · ${fmtResetAt(w.resetAt)}',
        details,
      );
      return;
    }

    final pct = (w.fraction * 100).round();
    final remaining = (w.cap - w.used).clamp(0.0, w.cap);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _warningChannelId,
        _warningChannelName,
        channelDescription: _warningChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      notificationId,
      '${w.label} at $pct%',
      '\$${remaining.toStringAsFixed(2)} left · ${fmtResetAt(w.resetAt)}',
      details,
    );
  }

  Future<void> _showSyncFailed(String accountKey, String accountLabel) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _syncHealthChannelId,
        _syncHealthChannelName,
        channelDescription: _syncHealthChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      accountKey.hashCode & 0x7fffffff,
      'Sync failed',
      accountLabel,
      details,
    );
  }
}
