import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import 'company_providers.dart';

class CompanyProfileScreen extends ConsumerWidget {
  const CompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyProvider);
    final trust = ref.watch(companyTrustProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.companyProfile)),
      body: AsyncBody(
        value: company,
        onRetry: () => ref.invalidate(companyProvider),
        builder: (c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (c.region != null) InfoRow(S.region, c.region!),
                  if (c.city != null) InfoRow(S.city, c.city!),
                  if (c.phone != null) InfoRow(S.phone, c.phone!),
                  InfoRow('Holat', switch (c.verificationStatus) {
                    'VERIFIED' => S.verifiedCompany,
                    'PENDING' => 'Tekshiruvda',
                    'REJECTED' => 'Rad etilgan',
                    _ => S.notVerifiedCompany,
                  }),
                ]),
              ),
            ),
            const SectionTitle('Ishonch belgilari'),
            AsyncBody(
              value: trust,
              onRetry: () => ref.invalidate(companyTrustProvider),
              builder: (t) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    InfoRow(S.workersManaged, '${t.workersManaged}'),
                    InfoRow(S.verifiedShifts, '${t.verifiedShifts}'),
                    InfoRow(S.completedVacancies, '${t.completedVacancies}'),
                    InfoRow('Faol loyihalar', '${t.activeProjects}'),
                    if (t.memberSince != null) InfoRow(S.memberSince, fmtDate(t.memberSince)),
                  ]),
                ),
              ),
            ),
            if (c.verificationStatus == 'UNVERIFIED' || c.verificationStatus == 'REJECTED') ...[
              const SizedBox(height: 16),
              const Text(
                "Tasdiqlangan belgisi faqat Worker OS jamoasi kompaniya STIR ma'lumotlarini tekshirgandan keyin beriladi.",
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.verified_outlined),
                label: const Text(S.requestVerification),
                onPressed: () async {
                  final stir = await promptText(context, title: S.requestVerification, hint: S.stir, confirm: 'Yuborish', minLength: 9);
                  if (stir == null || !context.mounted) return;
                  if (!RegExp(r'^\d{9}$').hasMatch(stir)) return showSnack(context, 'STIR 9 ta raqamdan iborat', error: true);
                  await runAction(context, () => ref.read(repoProvider).requestVerification(cidFrom(ref), stir), success: "So'rov yuborildi");
                  ref.invalidate(companyProvider);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
