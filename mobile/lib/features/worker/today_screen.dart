import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/db/database.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/location/location_service.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../common/notification_bell.dart';

const _cacheKey = 'today';

/// Fresh server state; refetched whenever a sync changed something on the server.
final todayRemoteProvider = FutureProvider.autoDispose<TodayData>((ref) async {
  ref.watch(serverRevisionProvider);
  final raw = await ref.read(repoProvider).todayRaw();
  await ref.read(databaseProvider).putCache(_cacheKey, encodeJson(raw));
  return TodayData.fromJson(raw);
});

/// Last known state for instant, offline-capable startup.
final todayCacheProvider = FutureProvider.autoDispose<TodayData?>((ref) async {
  final c = await ref.read(databaseProvider).getCache(_cacheKey);
  return c == null ? null : TodayData.fromJson(decodeJson(c.json), fetchedAt: c.updatedAt);
});

enum WorkPhase { notStarted, working, finished }

/// What the worker should see right now: server state merged with not-yet-synced local taps.
class EffectiveToday {
  EffectiveToday({required this.phase, this.since, this.until, this.siteId, this.pending = false, this.staleOpenShift});
  final WorkPhase phase;
  final DateTime? since;
  final DateTime? until;
  final String? siteId;
  final bool pending;
  final Shift? staleOpenShift;
}

EffectiveToday deriveToday(TodayData? data, List<PendingEvent> unsynced) {
  final local = unsynced.where((e) => e.status == 'PENDING' || e.status == 'SYNCING').toList()..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final open = data?.openShift;
  final stale = open != null && open.isStale ? open : null;
  if (local.isNotEmpty) {
    final last = local.last;
    if (last.type == 'WORK_STARTED') return EffectiveToday(phase: WorkPhase.working, since: last.occurredAt, siteId: last.siteId, pending: true);
    final start = local.where((e) => e.type == 'WORK_STARTED').lastOrNull;
    return EffectiveToday(phase: WorkPhase.finished, since: start?.occurredAt ?? open?.startedAt, until: last.occurredAt, siteId: last.siteId, pending: true);
  }
  if (open != null && !open.isStale) return EffectiveToday(phase: WorkPhase.working, since: open.startedAt, siteId: open.siteId);
  final ended = data?.todayShifts.where((s) => s.endedAt != null).toList() ?? const [];
  if (ended.isNotEmpty) {
    final last = ended.last;
    return EffectiveToday(phase: WorkPhase.finished, since: last.startedAt, until: last.endedAt, siteId: last.siteId, staleOpenShift: stale);
  }
  return EffectiveToday(phase: WorkPhase.notStarted, staleOpenShift: stale);
}

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> with WidgetsBindingObserver {
  String? _selectedSiteId;
  bool _busy = false;
  String? _busyLabel;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Re-render the running duration every minute.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(syncServiceProvider).value?.syncNow(force: true));
      ref.invalidate(todayRemoteProvider);
    }
  }

  Future<void> _refresh() async {
    await ref.read(syncServiceProvider).value?.syncNow(force: true);
    ref.invalidate(todayRemoteProvider);
    try {
      await ref.read(todayRemoteProvider.future);
    } catch (_) {}
  }

  TodayAssignment? _assignmentFor(TodayData data, EffectiveToday eff) {
    final byId = {for (final a in data.assignments) a.site.id: a};
    if (eff.phase == WorkPhase.working && eff.siteId != null && byId[eff.siteId] != null) return byId[eff.siteId];
    if (_selectedSiteId != null && byId[_selectedSiteId] != null) return byId[_selectedSiteId];
    return data.assignments.firstOrNull;
  }

  Future<void> _start(TodayAssignment a) async {
    final sync = ref.read(syncServiceProvider).value;
    if (sync == null) return;
    setState(() {
      _busy = true;
      _busyLabel = S.gettingLocation;
    });
    try {
      final loc = await ref.read(locationServiceProvider).current();
      if (loc is LocationFailed) {
        if (mounted) await _locationProblem(loc);
        return;
      }
      final p = loc as LocationOk;
      final d = distanceMeters(a.site.latitude, a.site.longitude, p.latitude, p.longitude);
      if (geofenceVerdict(d, a.site.radiusMeters, p.accuracy) == GeofenceVerdict.outside) {
        if (mounted) await _errorDialog(S.outsideSite(d.round()));
        return;
      }
      setState(() => _busyLabel = S.syncing);
      final r = await sync.record(
        type: 'WORK_STARTED',
        siteId: a.site.id,
        siteName: a.site.name,
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        isMocked: p.isMocked,
      );
      if (mounted) await _handleDelivery(r, success: S.startedAt(fmtTime(DateTime.now())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end(String siteId, String? siteName) async {
    final sync = ref.read(syncServiceProvider).value;
    if (sync == null) return;
    if (!await confirmDialog(context, title: S.confirmEndTitle, body: S.confirmEndBody, confirm: S.endWork, danger: true)) return;
    setState(() {
      _busy = true;
      _busyLabel = S.gettingLocation;
    });
    try {
      // Location is evidence, not a gate, for checkout: proceed even when GPS fails.
      final loc = await ref.read(locationServiceProvider).current(timeout: const Duration(seconds: 12));
      final p = loc is LocationOk ? loc : null;
      setState(() => _busyLabel = S.syncing);
      final r = await sync.record(
        type: 'WORK_ENDED',
        siteId: siteId,
        siteName: siteName,
        latitude: p?.latitude,
        longitude: p?.longitude,
        accuracy: p?.accuracy,
        isMocked: p?.isMocked,
      );
      if (mounted) await _handleDelivery(r, success: S.endedAt(fmtTime(DateTime.now())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleDelivery(Delivery r, {required String success}) async {
    switch (r.outcome) {
      case DeliveryOutcome.accepted:
        showSnack(context, success);
        ref.invalidate(todayRemoteProvider);
      case DeliveryOutcome.queuedOffline:
        showSnack(context, S.offlineSaved);
      case DeliveryOutcome.rejected:
        final pending = ref.read(unsyncedEventsProvider).value ?? const [];
        for (final e in pending.where((e) => e.status == 'REJECTED')) {
          await ref.read(databaseProvider).acknowledge(e.clientEventId);
        }
        if (mounted) await _errorDialog(r.message ?? S.unknownError);
        ref.invalidate(todayRemoteProvider);
    }
  }

  Future<void> _errorDialog(String message) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.info_outline_rounded, size: 40, color: AppColors.warning),
          content: Text(message, style: const TextStyle(fontSize: 17), textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text(S.close))],
        ),
      );

  Future<void> _locationProblem(LocationFailed f) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.location_off_rounded, size: 40, color: AppColors.danger),
          content: Text(f.message, style: const TextStyle(fontSize: 17), textAlign: TextAlign.center),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.close)),
            if (f.canOpenSettings)
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () {
                  Navigator.pop(c);
                  unawaited(ref.read(locationServiceProvider).openSettings(f.problem));
                },
                child: const Text(S.openSettings),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider); // keep the outbox processor alive while the worker UI is open
    final remote = ref.watch(todayRemoteProvider);
    final cache = ref.watch(todayCacheProvider);
    final unsynced = ref.watch(unsyncedEventsProvider).value ?? const <PendingEvent>[];
    final data = remote.value ?? cache.value;
    final remoteError = remote.hasError ? ApiError.from(remote.error!) : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(S.tabToday),
          Text(fmtDate(DateTime.now()), style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w400)),
        ]),
        actions: const [NotificationBell()],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Builder(builder: (context) {
          if (data == null) {
            if (remoteError != null) return ListView(children: [SizedBox(height: 400, child: ErrorView(error: remoteError, onRetry: _refresh))]);
            return const LoadingView();
          }
          final eff = deriveToday(data, unsynced);
          final assignment = _assignmentFor(data, eff);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (remoteError != null && remoteError.isNetwork) _OfflineNote(fetchedAt: data.fetchedAt),
              _OutboxBanner(events: unsynced, onSync: () => ref.read(syncServiceProvider).value?.syncNow(force: true)),
              if (data.assignments.isEmpty && eff.phase != WorkPhase.working)
                _NoSite(onJobs: () => context.go('/worker/jobs'))
              else if (assignment != null) ...[
                _SiteCard(
                  assignment: assignment,
                  all: data.assignments,
                  locked: eff.phase == WorkPhase.working,
                  onSelect: (id) => setState(() => _selectedSiteId = id),
                ),
                const SizedBox(height: 12),
                if (eff.staleOpenShift != null) const _Warning(S.staleShift),
                _StatusCard(eff: eff),
                const SizedBox(height: 16),
                if (eff.phase == WorkPhase.finished)
                  // The day is done: no loud START button; a second shift stays possible but deliberate.
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _start(assignment),
                    icon: const Icon(Icons.replay),
                    label: const Text('Yana ish boshlash (yangi smena)'),
                  )
                else
                  _BigButton(
                    busy: _busy,
                    busyLabel: _busyLabel,
                    phase: eff.phase,
                    onStart: () => _start(assignment),
                    onEnd: () => _end(eff.siteId ?? assignment.site.id, assignment.site.name),
                  ),
                if (assignment.isResident) ...[const SizedBox(height: 12), const _Hint(S.residentHint)],
              ],
              if (data.openTasks > 0) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_rounded, color: AppColors.primary),
                    title: const Text(S.openTasks),
                    trailing: CircleAvatar(radius: 14, child: Text('${data.openTasks}')),
                    onTap: () => context.go('/worker/work?tab=tasks'),
                  ),
                ),
              ],
              if (data.todayShifts.isNotEmpty) ...[
                const SectionTitle('Bugungi smenalar'),
                for (final s in data.todayShifts)
                  RecordTile(
                    title: '${fmtTime(s.startedAt)} – ${s.endedAt == null ? '…' : fmtTime(s.endedAt)}',
                    lines: [s.siteName ?? ''],
                    badges: [Pill(shiftStatusLabel(s.status), color: shiftStatusColor(s.status))],
                    onTap: () => context.push('/shift/${s.id}'),
                  ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({required this.assignment, required this.all, required this.locked, required this.onSelect});
  final TodayAssignment assignment;
  final List<TodayAssignment> all;
  final bool locked;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = assignment.site;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.location_city_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(s.name, style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 4),
          Text(assignment.company.name, style: const TextStyle(color: AppColors.muted)),
          if (s.address != null) Text(s.address!, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          Text(S.shiftHours(s.shiftStart, s.shiftEnd), style: const TextStyle(fontWeight: FontWeight.w600)),
          if (all.length > 1 && !locked) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: s.id,
              decoration: const InputDecoration(labelText: S.chooseSite),
              items: [for (final a in all) DropdownMenuItem(value: a.site.id, child: Text(a.site.name, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => v == null ? null : onSelect(v),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.eff});
  final EffectiveToday eff;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = switch (eff.phase) {
      WorkPhase.notStarted => (Icons.schedule_rounded, AppColors.muted, S.notStarted, null),
      WorkPhase.working => (
          Icons.construction_rounded,
          AppColors.start,
          S.workingNow,
          '${S.startedAt(fmtTime(eff.since))} · ${fmtMinutes(DateTime.now().difference(eff.since ?? DateTime.now()).inMinutes.clamp(0, 100000))}',
        ),
      WorkPhase.finished => (Icons.check_circle_rounded, AppColors.verified, S.finishedToday, '${fmtTime(eff.since)} – ${fmtTime(eff.until)}'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 16)),
              if (eff.pending) ...[const SizedBox(height: 6), const Pill(S.pendingSync, color: AppColors.warning, icon: Icons.cloud_upload_outlined)],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.busy, required this.phase, required this.onStart, required this.onEnd, this.busyLabel});
  final bool busy;
  final String? busyLabel;
  final WorkPhase phase;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final working = phase == WorkPhase.working;
    final color = working ? AppColors.end : AppColors.start;
    return Semantics(
      button: true,
      label: working ? S.endWork : S.startWork,
      child: SizedBox(
        height: 96,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color, disabledBackgroundColor: color.withValues(alpha: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          onPressed: busy ? null : (working ? onEnd : onStart),
          child: busy
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                  const SizedBox(width: 14),
                  Text(busyLabel ?? S.loading, style: const TextStyle(color: Colors.white, fontSize: 18)),
                ])
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(working ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded, size: 34, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(working ? S.endWork : S.startWork, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                ]),
        ),
      ),
    );
  }
}

class _OutboxBanner extends ConsumerWidget {
  const _OutboxBanner({required this.events, required this.onSync});
  final List<PendingEvent> events;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = events.where((e) => e.status == 'PENDING' || e.status == 'SYNCING').toList();
    final rejected = events.where((e) => e.status == 'REJECTED' && !e.acknowledged).toList();
    return Column(children: [
      if (pending.isNotEmpty)
        Card(
          color: const Color(0xFFFFF4E0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.cloud_upload_outlined, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(S.pendingCount(pending.length), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              ]),
              const Padding(padding: EdgeInsets.only(left: 34, top: 2), child: Text(S.offlineSaved)),
              Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onSync, icon: const Icon(Icons.sync), label: const Text(S.syncNow))),
            ]),
          ),
        ),
      for (final r in rejected)
        Card(
          color: const Color(0xFFFDECEC),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${r.type == 'WORK_STARTED' ? 'Ish boshlash' : 'Ish yakunlash'} (${fmtTime(r.occurredAt)}) — ${S.syncRejected}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
              Padding(padding: const EdgeInsets.only(left: 34, top: 2), child: Text(r.errorMessage ?? '')),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => ref.read(databaseProvider).acknowledge(r.clientEventId), child: const Text('Tushunarli')),
              ),
            ]),
          ),
        ),
      if (pending.isNotEmpty || rejected.isNotEmpty) const SizedBox(height: 12),
    ]);
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.fetchedAt});
  final DateTime fetchedAt;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(child: Text('${S.offline} ${S.lastUpdated}: ${fmtDateTime(fetchedAt)}', style: const TextStyle(color: AppColors.muted))),
        ]),
      );
}

class _NoSite extends StatelessWidget {
  const _NoSite({required this.onJobs});
  final VoidCallback onJobs;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 420,
        child: EmptyState(icon: Icons.location_off_outlined, title: S.noSiteTitle, body: S.noSiteBody, action: S.browseJobs, onAction: onJobs),
      );
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          color: const Color(0xFFFFF4E0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ]),
          ),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.home_work_outlined, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted))),
      ]);
}
