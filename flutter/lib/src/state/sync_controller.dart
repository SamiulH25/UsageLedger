/// Owns background syncing: periodic refresh, last-sync bookkeeping, and the
/// user-configurable interval persisted in settings.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../background.dart';
import '../data/usage_repository.dart';
import '../services/limit_notifier.dart';

class SyncController extends ChangeNotifier {
  final UsageRepository _repo;
  final LimitNotifier? _notifier;

  /// All intervals offered in settings, in minutes.
  static const List<int> intervalChoices = [0, 5, 15, 30, 60];

  static const String _intervalKey = 'syncIntervalMinutes';
  static const int _defaultInterval = 15;

  Timer? _timer;
  bool _syncing = false;
  DateTime? _lastSyncAt;
  int _intervalMinutes = _defaultInterval;
  String? _lastError;

  SyncController({UsageRepository? repo, LimitNotifier? notifier})
    : _repo = repo ?? UsageRepository.instance,
      _notifier = notifier;

  bool get syncing => _syncing;
  DateTime? get lastSyncAt => _lastSyncAt;
  int get intervalMinutes => _intervalMinutes;
  String? get lastError => _lastError;

  /// Load persisted interval and start the auto-sync timer.
  Future<void> start() async {
    final stored = await _repo.setting(_intervalKey);
    final parsed = stored == null ? null : int.tryParse(stored);
    _intervalMinutes = parsed ?? _defaultInterval;
    _applyTimer();
    // Initial sync when data is stale or missing.
    if (_intervalMinutes > 0) await sync();
  }

  Future<void> setInterval(int minutes) async {
    _intervalMinutes = minutes;
    await _repo.setSettingValue(_intervalKey, '$minutes');
    _applyTimer();
    if (Platform.isAndroid) {
      try {
        await scheduleBackgroundSync(minutes);
      } catch (e) {
        debugPrint('background reschedule failed: $e');
      }
    }
    notifyListeners();
  }

  void _applyTimer() {
    _timer?.cancel();
    if (_intervalMinutes <= 0) return;
    _timer = Timer.periodic(Duration(minutes: _intervalMinutes), (_) => sync());
  }

  Future<bool> sync() async {
    if (_syncing) return false;
    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final result = await _repo.refreshAll();
      _lastSyncAt = DateTime.now();
      if (result.failed.isNotEmpty) {
        _lastError = result.failed.first.error;
      } else {
        // Notify for pools that ran out; never block the sync on this.
        try {
          await _notifier?.evaluate(await _repo.overviews());
        } catch (e) {
          debugPrint('limit notify failed: $e');
        }
      }
      return result.failed.isEmpty;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
