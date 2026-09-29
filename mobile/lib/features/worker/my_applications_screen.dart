import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';

final myApplicationsProvider = FutureProvider.autoDispose<Paged<Application>>((ref) => ref.read(repoProvider).myApplications());

class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(myApplicationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.myApplications)),
      body: AsyncBody(
        value: apps,
        onRetry: () => ref.invalidate(myApplicationsProvider),
        isEmpty: (p) => p.items.isEmpty,
        empty: EmptyState(icon: Icons.inbox_outlined, title: S.noApplications, action: S.browseJobs, onAction: () => context.go('/worker/jobs')),
        builder: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(myApplicationsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: p.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (c, i) {
              final a = p.items[i];
              final color = switch (a.status) {
                'ACCEPTED' => AppColors.verified,
                'REJECTED' => AppColors.danger,
                'SHORTLISTED' => AppColors.primary,
                _ => AppColors.muted,
              };
              return RecordTile(
                title: a.vacancy?.title ?? '',
                lines: [a.vacancy?.company?.name ?? '', a.statusReason ?? '', fmtDate(a.createdAt)],
                badges: [Pill(applicationStatusLabel(a.status), color: color)],
                onTap: a.vacancy == null ? null : () => context.push('/vacancy/${a.vacancy!.id}'),
              );
            },
          ),
        ),
      ),
    );
  }
}
