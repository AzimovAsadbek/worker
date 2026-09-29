import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';

class WorkerShell extends StatelessWidget {
  const WorkerShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: S.tabToday),
            NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: S.tabJobs),
            NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: S.tabMyWork),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: S.tabProfile),
          ],
        ),
      );
}
