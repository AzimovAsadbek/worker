import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';

class CompanyShell extends StatelessWidget {
  const CompanyShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: S.tabDashboard),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: S.tabWorkers),
            NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: S.tabShifts),
            NavigationDestination(icon: Icon(Icons.menu), label: S.tabMore),
          ],
        ),
      );
}
