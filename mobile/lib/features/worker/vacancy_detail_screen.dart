import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import 'jobs_screen.dart';

final vacancyProvider = FutureProvider.autoDispose.family<Vacancy, String>((ref, id) => ref.read(repoProvider).vacancy(id));

class VacancyDetailScreen extends ConsumerWidget {
  const VacancyDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final note = await promptText(context, title: S.apply, hint: S.coverNote, required: false, confirm: S.apply);
    if (note == null || !context.mounted) return;
    await runAction(context, () => ref.read(repoProvider).apply(id, note), success: S.applied);
    ref.invalidate(vacancyProvider(id));
    ref.invalidate(jobsProvider);
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, String appId) async {
    if (!await confirmDialog(context, title: S.withdraw, danger: true)) return;
    if (!context.mounted) return;
    await runAction(context, () => ref.read(repoProvider).withdraw(appId));
    ref.invalidate(vacancyProvider(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(vacancyProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Vakansiya')),
      body: AsyncBody(
        value: v,
        onRetry: () => ref.invalidate(vacancyProvider(id)),
        builder: (v) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(v.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${fmtMoney(v.rateAmount, v.currency)} ${paymentPeriodLabel(v.paymentPeriod)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.start)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  InfoRow(S.category, categoryLabel(v.category), icon: Icons.handyman_outlined),
                  InfoRow(S.workersNeeded, '${v.workersNeeded}', icon: Icons.groups_outlined),
                  if (v.city != null || v.region != null) InfoRow(S.address, [v.city, v.region, v.address].whereType<String>().join(', '), icon: Icons.place_outlined),
                  if (v.startDate != null) InfoRow(S.startDate, fmtDate(v.startDate), icon: Icons.event_outlined),
                  if (v.durationDays != null) InfoRow(S.duration, '${v.durationDays} kun', icon: Icons.timelapse),
                ]),
              ),
            ),
            if (v.description != null) ...[const SectionTitle(S.description), Text(v.description!, style: const TextStyle(fontSize: 16))],
            if (v.requirements != null) ...[const SectionTitle(S.requirements), Text(v.requirements!, style: const TextStyle(fontSize: 16))],
            const SectionTitle(S.companyTrust),
            _TrustCard(v: v),
            const SizedBox(height: 24),
            if (v.myApplicationStatus != null && v.myApplicationStatus != 'WITHDRAWN') ...[
              Center(child: Pill('${S.myApplications}: ${applicationStatusLabel(v.myApplicationStatus!)}', color: AppColors.warning)),
              if ((v.myApplicationStatus == 'SUBMITTED' || v.myApplicationStatus == 'SHORTLISTED') && v.myApplicationId != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => _withdraw(context, ref, v.myApplicationId!), child: const Text(S.withdraw)),
              ],
            ] else if (v.canApply)
              FilledButton.icon(onPressed: () => _apply(context, ref), icon: const Icon(Icons.send_rounded), label: const Text(S.apply))
            else
              const Center(child: Text('Bu vakansiyaga ariza topshirib bo\'lmaydi', style: TextStyle(color: AppColors.muted))),
          ],
        ),
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.v});
  final Vacancy v;
  @override
  Widget build(BuildContext context) {
    final t = v.trust;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(v.company?.name ?? '', style: Theme.of(context).textTheme.titleMedium)),
            if (t?.verified ?? false) const Pill(S.verifiedCompany, color: AppColors.verified, icon: Icons.verified),
          ]),
          if (!(t?.verified ?? false)) const Padding(padding: EdgeInsets.only(top: 4), child: Text(S.notVerifiedCompany, style: TextStyle(color: AppColors.muted))),
          if (t != null) ...[
            const SizedBox(height: 8),
            InfoRow(S.workersManaged, '${t.workersManaged}'),
            InfoRow(S.verifiedShifts, '${t.verifiedShifts}'),
            InfoRow(S.completedVacancies, '${t.completedVacancies}'),
            if (t.memberSince != null) InfoRow(S.memberSince, fmtDate(t.memberSince)),
          ],
        ]),
      ),
    );
  }
}
