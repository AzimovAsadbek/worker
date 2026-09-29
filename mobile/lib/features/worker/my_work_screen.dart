import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';

final myShiftsProvider = FutureProvider.autoDispose<Paged<Shift>>((ref) {
  ref.watch(serverRevisionProvider);
  return ref.read(repoProvider).myShifts();
});
final myTasksProvider = FutureProvider.autoDispose<Paged<WorkTask>>((ref) => ref.read(repoProvider).myTasks());

class MyWorkScreen extends ConsumerWidget {
  const MyWorkScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(S.tabMyWork),
          bottom: const TabBar(labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700), tabs: [Tab(text: S.history), Tab(text: S.tasks)]),
        ),
        body: const TabBarView(children: [_History(), _Tasks()]),
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(myShiftsProvider);
    return AsyncBody(
      value: shifts,
      onRetry: () => ref.invalidate(myShiftsProvider),
      isEmpty: (p) => p.items.isEmpty,
      empty: const EmptyState(icon: Icons.history_rounded, title: S.noHistory, body: S.noHistoryBody),
      builder: (p) {
        final verifiedMinutes = p.items.where((s) => s.status == 'VERIFIED').fold<int>(0, (a, s) => a + s.verifiedMinutes);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(myShiftsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: p.items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (c, i) {
              if (i == 0) {
                return Card(
                  color: const Color(0xFFE7F5F1),
                  child: ListTile(
                    leading: const Icon(Icons.verified_rounded, color: AppColors.verified, size: 32),
                    title: Text(fmtMinutes(verifiedMinutes), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    subtitle: Text('${S.verifiedHoursTotal} (${p.items.length} ta oxirgi smena)'),
                    trailing: TextButton(onPressed: () => context.go('/worker/profile'), child: const Text(S.details)),
                  ),
                );
              }
              final s = p.items[i - 1];
              return RecordTile(
                title: '${fmtYmd(s.businessDate)} · ${fmtTime(s.startedAt)}–${s.endedAt == null ? '…' : fmtTime(s.endedAt)}',
                lines: [[s.siteName, s.companyName].whereType<String>().join(' · ')],
                badges: [
                  Pill(shiftStatusLabel(s.status), color: shiftStatusColor(s.status)),
                  if (s.status == 'VERIFIED') Pill(fmtMinutes(s.verifiedMinutes), color: AppColors.verified, icon: Icons.verified_outlined),
                ],
                onTap: () => context.push('/shift/${s.id}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _Tasks extends ConsumerWidget {
  const _Tasks();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myTasksProvider);
    return AsyncBody(
      value: tasks,
      onRetry: () => ref.invalidate(myTasksProvider),
      isEmpty: (p) => p.items.isEmpty,
      empty: const EmptyState(icon: Icons.assignment_outlined, title: S.noTasks, body: S.noTasksBody),
      builder: (p) => RefreshIndicator(
        onRefresh: () => ref.refresh(myTasksProvider.future),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: p.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (c, i) {
            final t = p.items[i];
            return RecordTile(
              title: t.title,
              lines: [[qty(t.quantity, t.unit), t.siteName].where((x) => x != null && x.isNotEmpty).join(' · ')],
              badges: [Pill(taskStatusLabel(t.status), color: taskStatusColor(t.status))],
              onTap: () async {
                await context.push('/task/${t.id}');
                ref.invalidate(myTasksProvider);
              },
            );
          },
        ),
      ),
    );
  }
}
