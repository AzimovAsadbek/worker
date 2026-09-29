import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';
import '../common/notification_bell.dart';
import 'company_providers.dart';
import 'manual_attendance_sheet.dart';

String dayStatusLabel(String s) => switch (s) {
      'ON_SITE' => S.onSite,
      'CHECKED_OUT' => S.checkedOut,
      'ABSENT' => S.absent,
      'NOT_YET' => S.notYet,
      'DAY_OFF' => S.dayOff,
      'PENDING_CHECKOUT' => S.pendingCheckout,
      _ => s,
    };

Color dayStatusColor(String s) => switch (s) {
      'ON_SITE' => AppColors.start,
      'CHECKED_OUT' => AppColors.verified,
      'ABSENT' => AppColors.danger,
      'PENDING_CHECKOUT' => AppColors.warning,
      _ => AppColors.muted,
    };

/// Foreman opens the app → within 10 seconds: how many today, who is absent, late, not checked out.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _siteId;

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(activeMembershipProvider);
    final dash = ref.watch(dashboardProvider(_siteId));
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m?.company.name ?? ''),
          Text('${roleLabel(m?.role ?? Role.foreman)} · ${fmtDate(DateTime.now())}', style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w400)),
        ]),
        actions: const [NotificationBell()],
      ),
      body: AsyncBody(
        value: dash,
        onRetry: () => ref.invalidate(dashboardProvider(_siteId)),
        builder: (d) {
          if (d.sites.isEmpty && _siteId == null) {
            return EmptyState(
              icon: Icons.location_city_outlined,
              title: S.noSites,
              body: m?.isManagement ?? false ? S.createFirstSite : 'Sizga hali obyekt biriktirilmagan. Administrator bilan bog\'laning.',
              action: (m?.isManagement ?? false) ? S.createSite : null,
              onAction: () => context.push('/company/more/sites'),
            );
          }
          final t = d.totals;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(dashboardProvider(_siteId).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              children: [
                if (d.sites.length > 1 || _siteId != null)
                  SizedBox(
                    height: 48,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text(S.all), selected: _siteId == null, onSelected: (_) => setState(() => _siteId = null))),
                      for (final s in d.sites)
                        Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s.name), selected: _siteId == s.siteId, onSelected: (_) => setState(() => _siteId = s.siteId))),
                    ]),
                  ),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                  children: [
                    StatTile(value: '${t['present']}/${t['assigned']}', label: S.present, color: AppColors.start),
                    StatTile(value: '${t['absent']}', label: S.absent, color: t['absent'] > 0 ? AppColors.danger : null),
                    StatTile(value: '${t['late']}', label: S.late, color: t['late'] > 0 ? AppColors.warning : null),
                    StatTile(value: '${t['onSite']}', label: S.onSite),
                    StatTile(value: '${t['pendingCheckout']}', label: S.pendingCheckout, color: t['pendingCheckout'] > 0 ? AppColors.warning : null),
                    StatTile(value: '${t['notYet']}', label: S.notYet),
                  ],
                ),
                const SizedBox(height: 8),
                if (t['awaitingVerification'] > 0 || t['openDisputes'] > 0 || t['tasksAwaitingReview'] > 0)
                  Card(
                    child: Column(children: [
                      if (t['awaitingVerification'] > 0)
                        _Action(icon: Icons.fact_check_outlined, label: S.awaitingVerification, count: t['awaitingVerification'], onTap: () => context.go('/company/shifts')),
                      if (t['tasksAwaitingReview'] > 0)
                        _Action(icon: Icons.assignment_turned_in_outlined, label: S.tasksAwaitingReview, count: t['tasksAwaitingReview'], onTap: () => context.push('/company/more/tasks')),
                      if (t['openDisputes'] > 0) _Action(icon: Icons.gavel_rounded, label: S.openDisputes, count: t['openDisputes'], onTap: () => context.push('/company/more/disputes')),
                    ]),
                  ),
                for (final site in d.sites) ...[
                  SectionTitle('${site.name}  ·  ${site.shiftStart}–${site.shiftEnd}'),
                  if (!site.isWorkDay) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Bugun dam olish kuni', style: TextStyle(color: AppColors.muted))),
                  if (site.workers.isEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add_alt_1_outlined),
                        title: const Text(S.noWorkers),
                        subtitle: const Text(S.addFirstWorker),
                        onTap: () => context.push('/company/workers/add'),
                      ),
                    )
                  else
                    Card(child: Column(children: [for (final w in site.workers) _WorkerRow(w: w, siteId: site.siteId)])),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.count, required this.onTap});
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 14, child: Text('$count', style: const TextStyle(fontSize: 13))), const Icon(Icons.chevron_right)]),
        onTap: onTap,
      );
}

class _WorkerRow extends ConsumerWidget {
  const _WorkerRow({required this.w, required this.siteId});
  final DashboardWorker w;
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = w.shift;
    final times = shift == null ? null : '${fmtTime(shift.startedAt)}${shift.endedAt != null ? '–${fmtTime(shift.endedAt)}' : ''}';
    return ListTile(
      title: Text(w.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([
        ?times,
        if (w.isLate) '${S.late} ${w.lateMinutes} daq',
        if (w.isResident) 'obyektda yashaydi',
      ].join(' · ')),
      trailing: Pill(dayStatusLabel(w.status), color: dayStatusColor(w.status)),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text(w.displayName, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(w.phone == null ? '' : prettyPhone(w.phone!))),
            if (shift != null)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Smenani ochish'),
                onTap: () {
                  Navigator.pop(c);
                  context.push('/company/shift/${shift.id}');
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text(S.manualAttendance),
              onTap: () {
                Navigator.pop(c);
                showManualAttendance(context, ref, workerId: w.userId, workerName: w.displayName, siteId: siteId, working: w.status == 'ON_SITE' || w.status == 'PENDING_CHECKOUT');
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
