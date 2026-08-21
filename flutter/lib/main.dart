import 'package:flutter/material.dart';

import 'src/screens/accounts_screen.dart';
import 'src/screens/add_account_screen.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/ui/theme.dart';

void main() {
  runApp(const AiUsageMonitorApp());
}

class AiUsageMonitorApp extends StatefulWidget {
  const AiUsageMonitorApp({super.key});

  @override
  State<AiUsageMonitorApp> createState() => _AiUsageMonitorAppState();
}

class _AiUsageMonitorAppState extends State<AiUsageMonitorApp> {
  int _tab = 0;

  Future<void> _openAdd() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAccountScreen(),
    );
    if (mounted) setState(() {}); // refresh tabs after adding
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Usage Monitor',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            HomeScreen(onOpenAdd: _openAdd),
            AccountsScreen(onOpenAdd: _openAdd),
            const HistoryScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Accounts',
            ),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          ],
        ),
      ),
    );
  }
}
