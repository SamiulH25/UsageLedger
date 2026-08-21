import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'src/data/usage_repository.dart';
import 'src/screens/accounts_screen.dart';
import 'src/screens/add_account_screen.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/state/app_scope.dart';
import 'src/state/sync_controller.dart';
import 'src/state/view_models.dart';
import 'src/background.dart';
import 'src/services/limit_notifier.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher);
    // Respect the persisted interval; the task itself clamps to >=15 min.
    final stored = await UsageRepository.instance.setting(
      'syncIntervalMinutes',
    );
    await scheduleBackgroundSync(int.tryParse(stored ?? '') ?? 15);
  }
  runApp(const UsageLedgerApp());
}

class UsageLedgerApp extends StatefulWidget {
  const UsageLedgerApp({super.key});

  @override
  State<UsageLedgerApp> createState() => _UsageLedgerAppState();
}

class _UsageLedgerAppState extends State<UsageLedgerApp> {
  final UsageRepository _repo = UsageRepository.instance;
  late final SyncController _sync;
  late final LimitNotifier _notifier;
  late final OverviewViewModel _overviewVm;
  late final AccountsViewModel _accountsVm;
  late final HistoryViewModel _historyVm;

  @override
  void initState() {
    super.initState();
    _notifier = LimitNotifier(repo: _repo);
    _sync = SyncController(repo: _repo, notifier: _notifier);
    _overviewVm = OverviewViewModel(repo: _repo, sync: _sync);
    _accountsVm = AccountsViewModel(repo: _repo);
    _historyVm = HistoryViewModel(repo: _repo);
    // Kick off initial loads; sync.start() also runs the first refresh.
    _overviewVm.load();
    _accountsVm.load();
    _historyVm.load();
    _sync.start();
    _notifier.init();
  }

  @override
  void dispose() {
    _overviewVm.dispose();
    _accountsVm.dispose();
    _historyVm.dispose();
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: _repo,
      sync: _sync,
      overviewVm: _overviewVm,
      accountsVm: _accountsVm,
      historyVm: _historyVm,
      child: MaterialApp(
        title: 'UsageLedger',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Pull-to-refresh must respond to mouse drag on desktop too.
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        home: MainShell(onDataChanged: _reloadAll),
      ),
    );
  }

  Future<void> _reloadAll() async {
    await Future.wait([
      _overviewVm.load(),
      _accountsVm.load(),
      _historyVm.load(),
    ]);
  }
}

class MainShell extends StatefulWidget {
  final Future<void> Function() onDataChanged;

  const MainShell({super.key, required this.onDataChanged});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  Future<void> _openAdd() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAccountScreen(),
    );
    await widget.onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onOpenAdd: _openAdd),
          AccountsScreen(onOpenAdd: _openAdd),
          const HistoryScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle),
              label: 'Accounts',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
