import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notifier.dart';
import '../state/devices_state.dart';
import '../state/notifications_state.dart';
import 'account_screen.dart';
import 'dashboard_screen.dart';
import 'devices_screen.dart';
import 'notifications_screen.dart';

/// Bottom navigation: Dashboard, Devices, Account.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final devices = context.read<DevicesState>();
      devices.onLocalConnected = (d) => Notifier.show(
            900000 + d.id,
            '${d.displayName} connected locally',
            'Controlled directly on your Wi-Fi, even without internet.',
            level: 'success',
          );
      devices.refresh();
      Notifier.init();
      context.read<NotificationsState>().start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop polling in the background to save battery and data.
    final active = state == AppLifecycleState.resumed;
    context.read<DevicesState>().setPaused(!active);
    final notes = context.read<NotificationsState>();
    if (active) {
      notes.start();
    } else if (state == AppLifecycleState.paused) {
      notes.stop();
    }
  }

  void goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final alerts = context.select<DevicesState, int>((s) => s.stats.alerts);
    final unread = context.select<NotificationsState, int>((s) => s.unread);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(onOpenDevices: () => goTo(1)),
          const DevicesScreen(),
          const NotificationsScreen(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: goTo,
        destinations: [
          NavigationDestination(
            icon: Badge(isLabelVisible: alerts > 0, label: Text('$alerts'), child: const Icon(Icons.space_dashboard_outlined)),
            selectedIcon: Badge(isLabelVisible: alerts > 0, label: Text('$alerts'), child: const Icon(Icons.space_dashboard_rounded)),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.developer_board_outlined),
            selectedIcon: Icon(Icons.developer_board_rounded),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_none_rounded)),
            selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_rounded)),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
