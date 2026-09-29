import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';

final _notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final (page, _) = await ref.read(repoProvider).notifications();
  return page.items;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(_notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.notifications),
        actions: [
          IconButton(
            tooltip: S.readAll,
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () async {
              await runAction(context, () => ref.read(repoProvider).readAll());
              ref.invalidate(_notificationsProvider);
            },
          ),
        ],
      ),
      body: AsyncBody(
        value: list,
        onRetry: () => ref.invalidate(_notificationsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyState(icon: Icons.notifications_off_outlined, title: S.noNotifications),
        builder: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(_notificationsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (c, i) {
              final n = items[i];
              return Card(
                color: n.isRead ? Colors.white : const Color(0xFFEAF1FF),
                child: ListTile(
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    Text(n.body),
                    const SizedBox(height: 4),
                    Text(fmtDateTime(n.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ]),
                  onTap: n.isRead
                      ? null
                      : () async {
                          await ref.read(repoProvider).markRead(n.id).catchError((_) {});
                          ref.invalidate(_notificationsProvider);
                        },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
