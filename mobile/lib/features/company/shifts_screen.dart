import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import 'company_providers.dart';

/// Verification queue: closed shifts waiting for the supervisor, flagged ones first.
class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key});
  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  bool _flaggedOnly = false;
  final Set<String> _selected = {};

  Future<void> _bulkVerify(List<Shift> shifts) async {
    final ids = _selected.isEmpty ? shifts.where((s) => s.status == 'CLOSED' && s.flags.isEmpty).map((s) => s.id).toList() : _selected.toList();
    if (ids.isEmpty) return;
    if (!await confirmDialog(context, title: '${ids.length} ta smenani tasdiqlaysizmi?', body: _selected.isEmpty ? 'Faqat belgisiz (muammosiz) yakunlangan smenalar tasdiqlanadi.' : null)) return;
    if (!mounted) return;
    final r = await runAction(context, () => ref.read(repoProvider).bulkVerify(cidFrom(ref), ids));
    if (r != null && mounted) {
      final (verified, skipped) = r;
      showSnack(context, 'Tasdiqlandi: ${verified.length}${skipped.isNotEmpty ? ', o\'tkazib yuborildi: ${skipped.length}' : ''}');
      setState(_selected.clear);
      ref.invalidate(reviewQueueProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(reviewQueueProvider(_flaggedOnly));
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.awaitingVerification),
        actions: [
          FilterChip(label: const Text(S.flags), selected: _flaggedOnly, onSelected: (v) => setState(() => _flaggedOnly = v)),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncBody(
        value: queue,
        onRetry: () => ref.invalidate(reviewQueueProvider(_flaggedOnly)),
        isEmpty: (p) => p.items.isEmpty,
        empty: const EmptyState(icon: Icons.task_alt_rounded, title: S.nothingToVerify, body: S.nothingToVerifyBody),
        builder: (p) {
          final items = [...p.items]..sort((a, b) {
              int rank(Shift s) => s.status == 'NEEDS_REVIEW' ? 0 : (s.flags.isNotEmpty ? 1 : (s.isOpen ? 3 : 2));
              return rank(a).compareTo(rank(b));
            });
          final closedClean = items.where((s) => s.status == 'CLOSED' && s.flags.isEmpty).length;
          return Column(children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(reviewQueueProvider(_flaggedOnly).future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (c, i) {
                    final s = items[i];
                    final selectable = s.isReviewable && s.endedAt != null;
                    return RecordTile(
                      leading: selectable
                          ? Checkbox(value: _selected.contains(s.id), onChanged: (v) => setState(() => v == true ? _selected.add(s.id) : _selected.remove(s.id)))
                          : const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.timelapse, color: AppColors.primary)),
                      title: s.worker?.displayName ?? '—',
                      lines: [
                        '${fmtYmd(s.businessDate)} · ${fmtTime(s.startedAt)}–${s.endedAt == null ? '…' : fmtTime(s.endedAt)}${s.endedAt == null ? '' : ' · ${fmtMinutes(s.workedMinutes)}'}',
                        s.siteName ?? '',
                      ],
                      badges: [
                        Pill(shiftStatusLabel(s.status), color: shiftStatusColor(s.status)),
                        for (final f in s.flags) Pill(flagLabel(f), color: AppColors.warning, icon: Icons.flag_outlined),
                      ],
                      onTap: () async {
                        await context.push('/company/shift/${s.id}');
                        ref.invalidate(reviewQueueProvider);
                      },
                    );
                  },
                ),
              ),
            ),
            if (_selected.isNotEmpty || closedClean > 0)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: FilledButton.icon(
                    onPressed: () => _bulkVerify(items),
                    icon: const Icon(Icons.done_all),
                    label: Text(_selected.isNotEmpty ? '${S.verifySelected} (${_selected.length})' : '${S.verifyAll} ($closedClean)'),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
