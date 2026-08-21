/// Tiny DI: an [InheritedWidget] that hands ViewModels + the sync controller
/// down the tree. Created once in [main].
library;

import 'package:flutter/widgets.dart';

import '../data/usage_repository.dart';
import 'sync_controller.dart';
import 'view_models.dart';

class AppScope extends InheritedWidget {
  final UsageRepository repository;
  final SyncController sync;
  final OverviewViewModel overviewVm;
  final AccountsViewModel accountsVm;
  final HistoryViewModel historyVm;

  const AppScope({
    super.key,
    required this.repository,
    required this.sync,
    required this.overviewVm,
    required this.accountsVm,
    required this.historyVm,
    required super.child,
  });

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
