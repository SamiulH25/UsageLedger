/// Owns background syncing: periodic refresh, last-sync bookkeeping, and the
/// user-configurable interval persisted in settings.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../background.dart';
import '../data/usage_repository.dart';
import '../data/widget_feed.dart';
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
  DateTime? _lastAttemptAt;
  DateTime? _lastSuccessAt;
  int _intervalMinutes = _defaultInterval;
  String? _lastError;

  SyncController({UsageRepository? repo, LimitNotifier? notifier})
    : _repo = repo ?? UsageRepository.instance,
      _notifier = notifier;

  bool get syncing => _syncing;
  DateTime? get lastAttemptAt => _lastAttemptAt;
  DateTime? get lastSuccessAt => _lastSuccessAt;
  DateTime? get lastSyncAt => _lastSuccessAt;
  int get intervalMinutes => _intervalMinutes;
  String? get lastError => _lastError;
  bool get syncFailed => _lastError != null && _lastAttemptAt != null;

  /// Load persisted interval and start the auto-sync timer.
  Future<void> start() async {
    final stored = await _repo.setting(_intervalKey);
    final parsed = stored == null ? null : int.tryParse(stored);
    _intervalMinutes = parsed ?? _defaultInterval;
    try {
      final accounts = await _repo.accounts();
      final latest = accounts
          .map((account) => account.lastRefreshAt)
          .where((value) => value > 0)
          .fold<int>(0, (max, value) => value > max ? value : max);
      if (latest > 0) {
        _lastSuccessAt = DateTime.fromMillisecondsSinceEpoch(latest);
      }
    } catch (e) {
      debugPrint('sync status load failed: $e');
    }
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
    _lastAttemptAt = DateTime.now();
    _lastError = null;
    notifyListeners();
    try {
      final result = await _repo.refreshAll();
      if (result.failed.isNotEmpty) {
        _lastError = conciseError(result.failed.first.error);
      } else {
        _lastSuccessAt = _lastAttemptAt;
      }
      // Notifications + widget; never block the sync on these.
      try {
        await _notifier?.evaluate(await _repo.overviews());
        await feedWidget(_repo);
      } catch (e) {
        debugPrint('post-sync extras failed: $e');
      }
      return result.failed.isEmpty;
    } catch (e) {
      _lastError = conciseError(e.toString());
      return false;
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

String conciseError(String? error) {
  final cleaned = (error ?? '')
      .replaceFirst(
        RegExp(r'^(Exception|ClientException|FormatException):\s*'),
        '',
      )
      .trim();
  if (cleaned.isEmpty) return 'Sync failed. Check the connection and API key.';
  if (cleaned.length <= 180) return cleaned;
  return '${cleaned.substring(0, 177)}…';
}
