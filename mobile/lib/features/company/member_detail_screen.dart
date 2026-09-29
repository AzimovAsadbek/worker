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
import '../worker/profile_screen.dart';
import 'company_providers.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberProvider(id));
    final actor = ref.watch(activeMembershipProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Xodim')),
      body: AsyncBody(
        value: member,
        onRetry: () => ref.invalidate(memberProvider(id)),
        builder: (m) {
          final isMgmt = actor?.isManagement ?? false;
          final active = m.assignments.where((a) => a.role == 'WORKER' || a.role == 'FOREMAN').toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: const CircleAvatar(radius: 24, child: Icon(Icons.person)),
                  title: Text(m.user.displayName, style: Theme.of(context).textTheme.titleLarge),
                  subtitle: Text([roleLabel(m.role), if (m.user.phone != null) prettyPhone(m.user.phone!), ?m.title].join('\n')),
                ),
              ),
              const SectionTitle(S.sites),
              Card(
                child: Column(children: [
                  if (active.isEmpty) const ListTile(title: Text('Obyektga biriktirilmagan')),
                  for (final a in active)
                    ListTile(
                      title: Text(a.siteName),
                      subtitle: a.role == 'WORKER' ? Text(a.isResident ? S.residentWorker : 'Kelib-ketadi') : const Text('Prorab'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          final repo = ref.read(repoProvider);
                          final cid = cidFrom(ref);
                          if (v == 'resident') await runAction(context, () => repo.setResident(cid, a.siteId, a.id, !a.isResident));
                          if (v == 'unassign' && context.mounted) {
                            final ok = await confirmDialog(context, title: 'Obyektdan olib tashlash?', danger: true);
                            if (ok && context.mounted) await runAction(context, () => repo.unassign(cid, a.siteId, a.id));
                          }
                          ref.invalidate(memberProvider(id));
                        },
                        itemBuilder: (_) => [
                          if (a.role == 'WORKER') PopupMenuItem(value: 'resident', child: Text(a.isResident ? 'Kelib-ketadi deb belgilash' : 'Obyektda yashaydi deb belgilash')),
                          const PopupMenuItem(value: 'unassign', child: Text('Obyektdan olib tashlash')),
                        ],
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add_location_alt_outlined),
                    title: const Text('Obyektga biriktirish'),
                    onTap: () async {
                      final sites = await ref.read(companySitesProvider.future);
                      final free = sites.where((s) => !active.any((a) => a.siteId == s.info.id)).toList();
                      if (!context.mounted) return;
                      final pick = await showModalBottomSheet<String>(
                        context: context,
                        builder: (c) => SafeArea(
                          child: ListView(shrinkWrap: true, children: [
                            if (free.isEmpty) const ListTile(title: Text("Bo'sh obyekt yo'q")),
                            for (final s in free) ListTile(title: Text(s.info.name), onTap: () => Navigator.pop(c, s.info.id)),
                          ]),
                        ),
                      );
                      if (pick == null || !context.mounted) return;
                      await runAction(context, () => ref.read(repoProvider).assign(cidFrom(ref), pick, m.userId), success: 'Biriktirildi');
                      ref.invalidate(memberProvider(id));
                    },
                  ),
                ]),
              ),
              if (m.role == Role.worker) ...[
                Consumer(builder: (c, ref, _) {
                  final identity = ref.watch(workerIdentityProvider(m.userId));
                  return AsyncBody(value: identity, onRetry: () => ref.invalidate(workerIdentityProvider(m.userId)), builder: (i) => IdentityView(identity: i));
                }),
                const SectionTitle("So'nggi smenalar"),
                Consumer(builder: (c, ref, _) {
                  final shifts = ref.watch(workerShiftsProvider(m.userId));
                  return AsyncBody(
                    value: shifts,
                    onRetry: () => ref.invalidate(workerShiftsProvider(m.userId)),
                    builder: (p) => Card(
                      child: Column(children: [
                        if (p.items.isEmpty) const ListTile(title: Text(S.noHistory)),
                        for (final s in p.items.take(10))
                          ListTile(
                            title: Text('${fmtYmd(s.businessDate)} · ${fmtTime(s.startedAt)}–${s.endedAt == null ? '…' : fmtTime(s.endedAt)}'),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Text(s.siteName ?? ''),
                                Pill(shiftStatusLabel(s.status), color: shiftStatusColor(s.status)),
                              ]),
                            ),
                            onTap: () => context.push('/company/shift/${s.id}'),
                          ),
                      ]),
                    ),
                  );
                }),
              ],
              if (isMgmt && m.userId != ref.read(sessionProvider).me?.id) ...[
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () async {
                    final suspend = m.status == 'ACTIVE';
                    await runAction(context, () => ref.read(repoProvider).updateMember(cidFrom(ref), m.id, {'status': suspend ? 'SUSPENDED' : 'ACTIVE'}));
                    ref.invalidate(memberProvider(id));
                  },
                  child: Text(m.status == 'ACTIVE' ? "Vaqtincha to'xtatish" : 'Qayta faollashtirish'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    if (!await confirmDialog(context, title: 'Kompaniyadan chiqarish?', body: 'Ish tarixi saqlanib qoladi (ishchining shaxsiy tarixida ham).', danger: true)) return;
                    if (!context.mounted) return;
                    final ok = await runAction(context, () async {
                      await ref.read(repoProvider).removeMember(cidFrom(ref), m.id);
                      return true;
                    });
                    if (ok == true && context.mounted) {
                      ref.invalidate(membersProvider);
                      context.pop();
                    }
                  },
                  child: const Text('Kompaniyadan chiqarish'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
