import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'src/data/usage_repository.dart';
import 'src/screens/accounts_screen.dart';
import 'src/screens/add_account_screen.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/onboarding_screen.dart';
import 'src/state/app_scope.dart';
import 'src/state/sync_controller.dart';
import 'src/state/view_models.dart';
import 'src/background.dart';
import 'src/services/limit_notifier.dart';
import 'src/services/device_actions.dart';
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
  bool? _onboarded;
  bool _notificationsInitialized = false;
  bool _openAddAfterOnboarding = false;

  @override
  void initState() {
    super.initState();
    _notifier = LimitNotifier(repo: _repo);
    _sync = SyncController(repo: _repo, notifier: _notifier);
    _overviewVm = OverviewViewModel(repo: _repo, sync: _sync);
    _accountsVm = AccountsViewModel(repo: _repo);
    _historyVm = HistoryViewModel(repo: _repo);
    _overviewVm.load();
    _accountsVm.load();
    _historyVm.load();
    deviceActionsChannel.setMethodCallHandler((call) async {
      if (call.method == 'syncNow') {
        await _sync.sync();
      }
    });
    _sync.start();
    _consumeSyncShortcut();
    _repo.setting('onboarded').then((value) {
      if (!mounted) return;
      setState(() => _onboarded = value == '1');
      if (value == '1') _initNotifications();
    });
  }

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    _notificationsInitialized = true;
    await _notifier.init();
  }

  Future<void> _completeOnboarding(bool openAddAccount) async {
    if (!mounted) return;
    setState(() {
      _onboarded = true;
      _openAddAfterOnboarding = openAddAccount;
    });
    await _initNotifications();
  }

  Future<void> _consumeSyncShortcut() async {
    if (await consumeSyncShortcut() && mounted) {
      await _sync.sync();
    }
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
        home: _onboarded == null
            ? const _Splash()
            : _onboarded!
            ? MainShell(
                onDataChanged: _reloadAll,
                openAddAccount: _openAddAfterOnboarding,
              )
            : OnboardingScreen(onDone: _completeOnboarding),
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
  final bool openAddAccount;

  const MainShell({
    super.key,
    required this.onDataChanged,
    this.openAddAccount = false,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  bool _openedInitialAddAccount = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAddAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _openedInitialAddAccount) return;
        _openedInitialAddAccount = true;
        _openAdd();
      });
    }
  }

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
          border: Border(top: BorderSide(color: AppColors.rule)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer),
              label: 'NOW',
            ),
            NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub),
              label: 'ACCOUNTS',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'HISTORY',
            ),
          ],
        ),
      ),
    );
  }
}

/// Held for the one frame it takes to read the onboarding flag.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
