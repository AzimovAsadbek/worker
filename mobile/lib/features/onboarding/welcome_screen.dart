import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// Shown once to brand-new users without any company membership.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider).me?.fullName ?? '';
    Widget choice(IconData icon, String title, String desc, VoidCallback onTap) => Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Icon(icon, size: 44, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Text('${S.welcomeTitle}${name.isEmpty ? '' : ' $name'}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 32),
            choice(Icons.engineering_rounded, S.iAmWorker, S.iAmWorkerDesc, () {
              ref.read(sessionProvider.notifier).finishOnboarding();
              context.go('/worker/today');
            }),
            const SizedBox(height: 12),
            choice(Icons.apartment_rounded, S.iAmCompany, S.iAmCompanyDesc, () => context.push('/create-company')),
            const SizedBox(height: 24),
            const Text(S.waitingForCompany, style: TextStyle(color: AppColors.muted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
