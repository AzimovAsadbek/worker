import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// One phone number can be a worker in company A and a foreman in company B.
class ContextSwitcherTile extends ConsumerWidget {
  const ContextSwitcherTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final supervisor = session.me?.supervisorMemberships ?? const <Membership>[];
    if (supervisor.isEmpty) return const SizedBox.shrink();
    final current = session.activeMembership;
    return ListTile(
      leading: const Icon(Icons.swap_horiz_rounded),
      title: const Text(S.switchContext),
      subtitle: Text(current == null ? S.workerMode : '${current.company.name} · ${roleLabel(current.role)}'),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          builder: (c) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(padding: EdgeInsets.all(16), child: Text(S.switchContext, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              ListTile(
                leading: const Icon(Icons.engineering_outlined),
                title: const Text(S.workerMode),
                trailing: current == null ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(c, workerContext),
              ),
              for (final m in supervisor)
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(m.company.name),
                  subtitle: Text(roleLabel(m.role)),
                  trailing: current?.id == m.id ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () => Navigator.pop(c, m.id),
                ),
              const SizedBox(height: 8),
            ]),
          ),
        );
        if (choice == null) return;
        await ref.read(sessionProvider.notifier).switchContext(choice);
        if (context.mounted) context.go(choice == workerContext ? '/worker/today' : '/company/dashboard');
      },
    );
  }
}
