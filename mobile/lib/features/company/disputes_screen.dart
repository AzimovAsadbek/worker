import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import 'company_providers.dart';

class DisputesScreen extends ConsumerWidget {
  const DisputesScreen({super.key});

  Future<void> _resolve(BuildContext context, WidgetRef ref, String id, bool accept) async {
    final text = await promptText(
      context,
      title: accept ? S.acceptDispute : S.rejectDispute,
      hint: accept ? "Masalan: kamera yozuvi bo'yicha tasdiqlandi" : 'Masalan: 17:00 da ketgani guvohlar tomonidan tasdiqlangan',
    );
    if (text == null || !context.mounted) return;
    await runAction(context, () => ref.read(repoProvider).resolveDispute(cidFrom(ref), id, accept: accept, resolution: text), success: 'Saqlandi');
    ref.invalidate(disputesProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(disputesProvider(null));
    return Scaffold(
      appBar: AppBar(title: const Text(S.disputes)),
      body: AsyncBody(
        value: list,
        onRetry: () => ref.invalidate(disputesProvider(null)),
        isEmpty: (p) => p.items.isEmpty,
        empty: const EmptyState(icon: Icons.gavel_rounded, title: S.noDisputes),
        builder: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(disputesProvider(null).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: p.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (c, i) {
              final d = p.items[i];
              final s = d.shift;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(d.worker?.displayName ?? '—', style: Theme.of(context).textTheme.titleMedium)),
                      Pill(d.status == 'OPEN' ? 'Ochiq' : (d.status == 'ACCEPTED' ? 'Qabul qilindi' : 'Rad etildi'),
                          color: d.status == 'OPEN' ? AppColors.warning : (d.status == 'ACCEPTED' ? AppColors.verified : AppColors.danger)),
                    ]),
                    if (s != null) Text('${fmtYmd(s.businessDate)} · ${d.siteName ?? ''} · qayd: ${fmtTime(s.startedAt)}–${s.endedAt == null ? '…' : fmtTime(s.endedAt)}', style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Text('Ishchi: "${d.reason}"', style: const TextStyle(fontSize: 16)),
                    if (d.claimedStart != null || d.claimedEnd != null)
                      Text("Da'vo: ${d.claimedStart != null ? fmtTime(d.claimedStart) : '…'} – ${d.claimedEnd != null ? fmtTime(d.claimedEnd) : '…'}", style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (d.resolution != null) Text('Javob: ${d.resolution}', style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (s != null) TextButton(onPressed: () => context.push('/company/shift/${s.id}'), child: const Text('Smena')),
                      const Spacer(),
                      if (d.status == 'OPEN') ...[
                        OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _resolve(context, ref, d.id, false), child: const Text(S.rejectDispute)),
                        const SizedBox(width: 8),
                        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _resolve(context, ref, d.id, true), child: const Text(S.acceptDispute)),
                      ],
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
