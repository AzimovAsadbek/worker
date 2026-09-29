import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../common/context_switcher.dart';
import '../common/settings_screen.dart';
import 'company_providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(activeMembershipProvider);
    final isMgmt = m?.isManagement ?? false;
    Widget tile(IconData icon, String title, String path, {String? subtitle}) => ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(path),
        );
    return Scaffold(
      appBar: AppBar(title: Text(m?.company.name ?? S.tabMore)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Column(children: [
              tile(Icons.location_city_outlined, '${S.projects} va ${S.sites.toLowerCase()}', '/company/more/sites'),
              tile(Icons.assignment_outlined, S.tasks, '/company/more/tasks'),
              tile(Icons.campaign_outlined, S.vacancies, '/company/more/vacancies'),
              tile(Icons.gavel_rounded, S.disputes, '/company/more/disputes'),
            ]),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              if (isMgmt) tile(Icons.business_outlined, S.companyProfile, '/company/more/profile'),
              tile(Icons.notifications_none, S.notifications, '/notifications'),
              tile(Icons.settings_outlined, S.settings, '/settings'),
              const ContextSwitcherTile(),
              ListTile(leading: const Icon(Icons.logout, color: AppColors.danger), title: const Text(S.logout), onTap: () => confirmLogout(context, ref)),
            ]),
          ),
        ],
      ),
    );
  }
}
