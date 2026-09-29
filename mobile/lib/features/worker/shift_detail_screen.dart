import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../common/timeline.dart';
import 'my_work_screen.dart';

final myShiftProvider = FutureProvider.autoDispose.family<ShiftDetail, String>((ref, id) => ref.read(repoProvider).myShift(id));

class ShiftDetailScreen extends ConsumerWidget {
  const ShiftDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _dispute(BuildContext context, WidgetRef ref, ShiftDetail d) async {
    final result = await showModalBottomSheet<(String, DateTime?, DateTime?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DisputeSheet(shift: d.shift),
    );
    if (result == null || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(repoProvider).openDispute(id, reason: result.$1, claimedStart: result.$2, claimedEnd: result.$3),
      success: S.disputeSent,
    );
    ref.invalidate(myShiftProvider(id));
    ref.invalidate(myShiftsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(myShiftProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Ish kuni')),
      body: AsyncBody(
        value: detail,
        onRetry: () => ref.invalidate(myShiftProvider(id)),
        builder: (d) {
          final s = d.shift;
          final hasOpenDispute = d.disputes.any((x) => x.status == 'OPEN');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(fmtYmd(s.businessDate), style: Theme.of(context).textTheme.titleLarge)),
                      Pill(shiftStatusLabel(s.status), color: shiftStatusColor(s.status)),
                    ]),
                    const SizedBox(height: 8),
                    InfoRow('Obyekt', s.siteName ?? '—'),
                    InfoRow('Boshlandi', fmtDateTime(s.startedAt)),
                    InfoRow('Yakunlandi', s.endedAt == null ? '—' : fmtDateTime(s.endedAt)),
                    InfoRow('Ishlangan', fmtMinutes(s.workedMinutes)),
                    if (s.status == 'VERIFIED') InfoRow('Tasdiqlangan', fmtMinutes(s.verifiedMinutes)),
                    if (s.isLate) InfoRow(S.late, '${s.lateMinutes} daq'),
                    if (s.reviewNote != null) InfoRow(S.comment, s.reviewNote!),
                  ]),
                ),
              ),
              if (s.flags.isNotEmpty) ...[
                const SectionTitle(S.flags),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final f in s.flags) Pill(flagLabel(f), color: AppColors.warning)]),
              ],
              if (d.disputes.isNotEmpty) ...[
                const SectionTitle(S.disputes),
                for (final x in d.disputes)
                  Card(
                    child: ListTile(
                      title: Text(x.reason),
                      subtitle: Text(x.resolution == null ? 'Ko\'rib chiqilmoqda' : 'Javob: ${x.resolution}'),
                      trailing: Pill(x.status == 'OPEN' ? 'Ochiq' : (x.status == 'ACCEPTED' ? 'Qabul qilindi' : 'Rad etildi'),
                          color: x.status == 'ACCEPTED' ? AppColors.verified : (x.status == 'OPEN' ? AppColors.warning : AppColors.danger)),
                    ),
                  ),
              ],
              const SectionTitle(S.timeline),
              EventTimeline(events: d.events),
              const SizedBox(height: 24),
              if (!s.isOpen && !hasOpenDispute)
                OutlinedButton.icon(onPressed: () => _dispute(context, ref, d), icon: const Icon(Icons.report_outlined), label: const Text(S.dispute)),
            ],
          );
        },
      ),
    );
  }
}

class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({required this.shift});
  final Shift shift;
  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  final _reason = TextEditingController();
  TimeOfDay? _start;
  TimeOfDay? _end;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime? _at(TimeOfDay? t, DateTime base) => t == null ? null : DateTime(base.year, base.month, base.day, t.hour, t.minute);

  @override
  Widget build(BuildContext context) {
    final s = widget.shift;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(S.dispute, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(controller: _reason, maxLines: 3, maxLength: 1000, decoration: InputDecoration(hintText: S.disputeHint, errorText: _error)),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(s.startedAt));
                if (t != null) setState(() => _start = t);
              },
              child: Text(_start == null ? S.claimedStart : '${S.claimedStart}: ${_start!.format(context)}', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(s.endedAt ?? s.startedAt));
                if (t != null) setState(() => _end = t);
              },
              child: Text(_end == null ? S.claimedEnd : '${S.claimedEnd}: ${_end!.format(context)}', textAlign: TextAlign.center),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final r = _reason.text.trim();
            if (r.length < 5) return setState(() => _error = 'Muammoni qisqacha yozing (kamida 5 harf)');
            final start = _at(_start, s.startedAt);
            var end = _at(_end, s.endedAt ?? s.startedAt);
            if (end != null && start == null && end.isBefore(s.startedAt)) end = end.add(const Duration(days: 1));
            if (start != null && end != null && !end.isAfter(start)) return setState(() => _error = "Tugash vaqti boshlanishdan keyin bo'lishi kerak");
            Navigator.pop(context, (r, start, end));
          },
          child: const Text('Yuborish'),
        ),
      ]),
    );
  }
}
