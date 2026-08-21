/// Android background refresh: a Workmanager periodic task that pulls every
/// account and fires limit notifications — even when the app is closed.
///
/// Desktop is unaffected (no Workmanager there; SyncController's Timer is
/// enough for a dev window).
library;

import 'package:workmanager/workmanager.dart';

import 'data/usage_repository.dart';
import 'services/limit_notifier.dart';

const _taskName = 'com.usageledger.periodicSync';
const _uniqueName = 'usageledger-sync';

/// Headless entry point. Must be top-level and annotated for the AOT snapshot.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await runBackgroundSync();
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// One background pass: refresh everything, then evaluate notifications.
Future<void> runBackgroundSync() async {
  final repo = UsageRepository.instance;
  final result = await repo.refreshAll();
  if (result.failed.isNotEmpty) return;
  final notifier = LimitNotifier(repo: repo);
  await notifier.init();
  await notifier.evaluate(await repo.overviews());
}

/// Register (or re-register with [intervalMinutes], minimum 15 on Android) the
/// periodic task; [intervalMinutes] <= 0 cancels it. No-op off Android.
Future<void> scheduleBackgroundSync(int intervalMinutes) async {
  if (intervalMinutes <= 0) {
    await Workmanager().cancelByUniqueName(_uniqueName);
    return;
  }
  // Android's WorkManager floor is 15 minutes.
  final frequency = Duration(
    minutes: intervalMinutes < 15 ? 15 : intervalMinutes,
  );
  await Workmanager().registerPeriodicTask(
    _uniqueName,
    _taskName,
    frequency: frequency,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
