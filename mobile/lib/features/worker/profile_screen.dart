import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../common/context_switcher.dart';
import '../common/settings_screen.dart';

final myIdentityProvider = FutureProvider.autoDispose<Identity>((ref) {
  ref.watch(serverRevisionProvider);
  return ref.read(repoProvider).myIdentity();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).me;
    final identity = ref.watch(myIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.tabProfile), actions: [IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined))]),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(sessionProvider.notifier).refreshMe().catchError((_) {});
          return ref.refresh(myIdentityProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: const CircleAvatar(radius: 26, child: Icon(Icons.person, size: 30)),
                title: Text(me?.fullName ?? '—', style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text([if (me != null) prettyPhone(me.phone), me?.workerProfile?.primaryTrade].whereType<String>().join('\n')),
                trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/profile/edit')),
              ),
            ),
            AsyncBody(
              value: identity,
              onRetry: () => ref.invalidate(myIdentityProvider),
              builder: (id) => IdentityView(identity: id),
            ),
            const SectionTitle('Boshqa'),
            Card(
              child: Column(children: [
                ListTile(leading: const Icon(Icons.inbox_outlined), title: const Text(S.myApplications), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/applications')),
                const ContextSwitcherTile(),
                ListTile(
                  leading: const Icon(Icons.add_business_outlined),
                  title: const Text(S.createCompany),
                  subtitle: const Text(S.iAmCompanyDesc),
                  onTap: () => context.push('/create-company'),
                ),
                ListTile(leading: const Icon(Icons.logout, color: AppColors.danger), title: const Text(S.logout), onTap: () => confirmLogout(context, ref)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Verified numbers (from supervisor-confirmed records) are always shown apart from self-reported claims.
class IdentityView extends StatelessWidget {
  const IdentityView({super.key, required this.identity});
  final Identity identity;
  @override
  Widget build(BuildContext context) {
    final v = identity.verified;
    final sr = identity.selfReported;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(S.verifiedWork, trailing: Pill(trustLevelLabel(v.trustLevel), color: AppColors.verified, icon: Icons.shield_outlined)),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15,
        children: [
          StatTile(value: '${v.verifiedWorkdays}', label: S.verifiedWorkdays, color: AppColors.verified),
          StatTile(value: fmtHours(v.verifiedHours), label: S.verifiedHours, color: AppColors.verified),
          StatTile(value: '${v.verifiedTasks}', label: S.verifiedTasks, color: AppColors.verified),
          StatTile(value: fmtPercent(v.attendanceRate), label: '${S.attendance} (90 kun)'),
          StatTile(value: fmtPercent(v.punctualityRate), label: S.punctuality),
          StatTile(value: '${v.verifiedEmployers}', label: S.employers),
        ],
      ),
      if (identity.employers.isNotEmpty) ...[
        const SectionTitle(S.employers),
        Card(
          child: Column(children: [
            for (final e in identity.employers)
              ListTile(
                leading: Icon(e.companyVerified ? Icons.verified : Icons.business_outlined, color: e.companyVerified ? AppColors.verified : AppColors.muted),
                title: Text(e.name),
                subtitle: Text('${e.verifiedDays} kun · ${fmtHours(e.verifiedHours)} soat${e.projects.isNotEmpty ? '\n${e.projects.join(', ')}' : ''}'),
              ),
          ]),
        ),
      ],
      const SectionTitle(S.selfReported),
      Card(
        color: const Color(0xFFF7F7F7),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: sr == null
              ? const Text("Profil to'ldirilmagan", style: TextStyle(color: AppColors.muted))
              : Column(children: [
                  if (sr.primaryTrade != null) InfoRow(S.trade, sr.primaryTrade!),
                  if (sr.experienceYears != null) InfoRow(S.experienceYears, '${sr.experienceYears}'),
                  if (sr.city != null) InfoRow(S.city, sr.city!),
                  if (sr.bio != null) InfoRow(S.bio, sr.bio!),
                ]),
        ),
      ),
    ]);
  }
}
