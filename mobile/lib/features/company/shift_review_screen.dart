import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../common/timeline.dart';
import 'company_providers.dart';

class ShiftReviewScreen extends ConsumerWidget {
  const ShiftReviewScreen({super.key, required this.id});
  final String id;

  void _refresh(WidgetRef ref) {
    ref.invalidate(companyShiftProvider(id));
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _verify(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: '60');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(S.verifyShift),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: S.breakMinutes, helperText: 'Tushlik/tanaffus vaqti ish vaqtidan ayiriladi', helperMaxLines: 2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text(S.verifyShift)),
        ],
      ),
    );
    final minutes = int.tryParse(ctrl.text) ?? 0;
    ctrl.dispose();
    if (ok != true || !context.mounted) return;
    await runAction(context, () => ref.read(repoProvider).verifyShift(cidFrom(ref), id, breakMinutes: minutes.clamp(0, 600)), success: 'Tasdiqlandi');
    _refresh(ref);
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await promptText(context, title: S.rejectShift, hint: S.reason, confirm: S.rejectShift);
    if (reason == null || !context.mounted) return;
    await runAction(context, () => ref.read(repoProvider).rejectShift(cidFrom(ref), id, reason), success: 'Rad etildi');
    _refresh(ref);
  }

  Future<void> _correct(BuildContext context, WidgetRef ref, Shift s) async {
    final result = await showModalBottomSheet<(DateTime, DateTime?, String, bool)>(context: context, isScrollControlled: true, builder: (_) => _CorrectSheet(shift: s));
    if (result == null || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(repoProvider).correctShift(cidFrom(ref), id, startedAt: result.$1, endedAt: result.$2, reason: result.$3, verify: result.$4, breakMinutes: result.$4 ? 60 : null),
      success: "To'g'rilandi",
    );
    _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(companyShiftProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Smena')),
      body: AsyncBody(
        value: detail,
        onRetry: () => ref.invalidate(companyShiftProvider(id)),
        builder: (d) {
          final s = d.shift;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(s.worker?.displayName ?? '—', style: Theme.of(context).textTheme.titleLarge)),
                      Pill(shiftStatusLabel(s.status), color: shiftStatusColor(s.status)),
                    ]),
                    if (s.worker?.phone != null) Text(prettyPhone(s.worker!.phone!), style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    InfoRow('Sana', fmtYmd(s.businessDate)),
                    InfoRow('Obyekt', s.siteName ?? '—'),
                    InfoRow('Boshlandi', fmtDateTime(s.startedAt)),
                    InfoRow('Yakunlandi', s.endedAt == null ? '—' : fmtDateTime(s.endedAt)),
                    InfoRow('Ishlangan', fmtMinutes(s.workedMinutes)),
                    if (d.originalStartAt != null && d.originalStartAt != s.startedAt) InfoRow('Asl boshlanish', fmtDateTime(d.originalStartAt)),
                    if (d.originalEndAt != null && d.originalEndAt != s.endedAt) InfoRow('Asl tugash', fmtDateTime(d.originalEndAt)),
                    if (s.isLate) InfoRow(S.late, '${s.lateMinutes} daq'),
                    if (s.isResident) const InfoRow('Rejim', S.residentWorker),
                    if (s.status == 'VERIFIED') InfoRow('Tasdiqlangan', fmtMinutes(s.verifiedMinutes)),
                    if (s.reviewNote != null) InfoRow(S.comment, s.reviewNote!),
                  ]),
                ),
              ),
              if (s.flags.isNotEmpty) ...[
                const SectionTitle(S.flags),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final f in s.flags) Pill(flagLabel(f), color: AppColors.warning, icon: Icons.flag_outlined)]),
                const SizedBox(height: 4),
                const Text('Belgilar — ogohlantirish, hukm emas. Ishchi bilan gaplashib qaror qiling.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
              if (d.disputes.isNotEmpty) ...[
                const SectionTitle(S.disputes),
                for (final x in d.disputes)
                  Card(child: ListTile(title: Text(x.reason), subtitle: Text(x.resolution ?? (x.claimedEnd != null ? 'Da\'vo: ${fmtTime(x.claimedEnd)} gacha' : '')))),
              ],
              const SectionTitle(S.timeline),
              EventTimeline(events: d.events, showLocation: true),
              const SizedBox(height: 20),
              if (s.isReviewable && s.endedAt != null) ...[
                FilledButton.icon(onPressed: () => _verify(context, ref), icon: const Icon(Icons.verified_outlined), label: const Text(S.verifyShift)),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(onPressed: () => _correct(context, ref, s), icon: const Icon(Icons.edit_calendar_outlined), label: const Text(S.correctShift)),
              if (s.isReviewable) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => _reject(context, ref),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text(S.rejectShift),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CorrectSheet extends StatefulWidget {
  const _CorrectSheet({required this.shift});
  final Shift shift;
  @override
  State<_CorrectSheet> createState() => _CorrectSheetState();
}

class _CorrectSheetState extends State<_CorrectSheet> {
  late DateTime _start = widget.shift.startedAt;
  late DateTime? _end = widget.shift.endedAt;
  final _reason = TextEditingController();
  bool _verify = true;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime base) async {
    final date = await showDatePicker(context: context, initialDate: base, firstDate: base.subtract(const Duration(days: 7)), lastDate: DateTime.now());
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(S.correctShift, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text("Asl yozuv o'chirilmaydi: o'zgarish sababi bilan tarixda saqlanadi.", style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            final d = await _pick(_start);
            if (d != null) setState(() => _start = d);
          },
          child: Text('Boshlanish: ${fmtDateTime(_start)}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            final d = await _pick(_end ?? _start);
            if (d != null) setState(() => _end = d);
          },
          child: Text('Tugash: ${_end == null ? '—' : fmtDateTime(_end)}'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _reason, maxLines: 2, decoration: InputDecoration(labelText: S.reason, errorText: _error)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _verify, onChanged: (v) => setState(() => _verify = v), title: const Text('Darhol tasdiqlash (tanaffus 60 daq)')),
        FilledButton(
          onPressed: () {
            if (_reason.text.trim().length < 3) return setState(() => _error = S.required);
            if (_end != null && !_end!.isAfter(_start)) return setState(() => _error = "Tugash vaqti boshlanishdan keyin bo'lishi kerak");
            if (_end != null && _end!.difference(_start).inHours >= 24) return setState(() => _error = "Smena 24 soatdan uzun bo'lishi mumkin emas");
            Navigator.pop(context, (_start, _end, _reason.text.trim(), _verify && _end != null));
          },
          child: const Text(S.save),
        ),
      ]),
    );
  }
}
