import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../data/repository.dart';

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(serverRevisionProvider);
  return ref.read(repoProvider).unreadCount();
});

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(unreadCountProvider).value ?? 0;
    return IconButton(
      tooltip: S.notifications,
      iconSize: 28,
      onPressed: () async {
        await context.push('/notifications');
        ref.invalidate(unreadCountProvider);
      },
      icon: Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: const Icon(Icons.notifications_none_rounded)),
    );
  }
}
