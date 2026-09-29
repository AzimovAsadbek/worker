import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.read(repoProvider).sessions());

const _categories = {
  'shift': 'Ish kunlari va eslatmalar',
  'tasks': 'Vazifalar',
  'attendance': 'Davomat (prorab uchun)',
  'applications': 'Arizalar',
  'disputes': "E'tirozlar",
  'system': 'Tizim xabarlari',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).me;
    final sessions = ref.watch(_sessionsProvider);
    if (me == null) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(me.fullName ?? '—'),
              subtitle: Text(prettyPhone(me.phone)),
            ),
          ),
          const SectionTitle(S.notifications),
          Card(
            child: Column(children: [
              for (final e in _categories.entries)
                SwitchListTile(
                  title: Text(e.value),
                  value: me.notificationPrefs[e.key]?['inApp'] ?? true,
                  onChanged: (v) async {
                    await runAction(context, () => ref.read(repoProvider).updatePrefs({e.key: {'inApp': v, 'push': v}}));
                    await ref.read(sessionProvider.notifier).refreshMe().catchError((_) {});
                  },
                ),
            ]),
          ),
          const SectionTitle(S.sessions),
          AsyncBody(
            value: sessions,
            onRetry: () => ref.invalidate(_sessionsProvider),
            builder: (list) => Card(
              child: Column(children: [
                for (final s in list)
                  ListTile(
                    leading: Icon(s['platform'] == 'ios' ? Icons.phone_iphone : Icons.phone_android),
                    title: Text((s['deviceName'] as String?) ?? (s['platform'] as String? ?? 'Qurilma')),
                    subtitle: Text('${S.lastUpdated}: ${fmtDateTime(DateTime.tryParse(s['lastUsedAt'] as String? ?? ''))}'),
                    trailing: s['isCurrent'] == true
                        ? const Pill('Shu qurilma', color: AppColors.verified)
                        : IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: () async {
                              await runAction(context, () => ref.read(repoProvider).revokeSession(s['id'] as String));
                              ref.invalidate(_sessionsProvider);
                            },
                          ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.logout),
            label: const Text(S.logout),
            onPressed: () => confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Warns when attendance taps are still waiting for the network — logging out would strand them.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final me = ref.read(sessionProvider).me;
  final pending = me == null ? const [] : await ref.read(databaseProvider).unsynced(me.id);
  if (!context.mounted) return;
  final ok = await confirmDialog(context, title: S.logoutConfirm, body: pending.isNotEmpty ? S.logoutPending : null, confirm: S.logout, danger: true);
  if (ok) await ref.read(sessionProvider.notifier).logout();
}
