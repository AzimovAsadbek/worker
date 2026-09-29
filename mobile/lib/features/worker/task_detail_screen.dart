import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_error.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../common/evidence_grid.dart';

final myTaskProvider = FutureProvider.autoDispose.family<WorkTask, String>((ref, id) => ref.read(repoProvider).myTask(id));

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _uploading = false;

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600, maxHeight: 1600);
    if (picked == null || !mounted) return;
    final comment = await promptText(context, title: S.comment, hint: 'Masalan: 3-qavat devori tayyor', required: false, confirm: S.save);
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final name = picked.name.toLowerCase().endsWith('.png') ? picked.name : '${picked.name.split('.').first}.jpg';
      await ref.read(repoProvider).uploadEvidence(widget.id, path: picked.path, filename: name, comment: comment);
      ref.invalidate(myTaskProvider(widget.id));
      if (mounted) showSnack(context, 'Rasm yuklandi');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, '${S.uploadFailed}: ${e.message}', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit(WorkTask t) async {
    final ctrl = TextEditingController(text: t.quantity == null ? '' : (t.quantity! == t.quantity!.roundToDouble() ? '${t.quantity!.toInt()}' : '${t.quantity}'));
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(S.submitTask),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (t.quantity != null)
            TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: S.completedQuantity, suffixText: unitLabel(t.unit))),
          const SizedBox(height: 8),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: S.comment)),
          if (t.evidence.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Maslahat: rasm qo\'shsangiz, tez tasdiqlanadi.', style: TextStyle(color: AppColors.warning))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text(S.submitTask)),
        ],
      ),
    );
    final q = double.tryParse(ctrl.text.replaceAll(',', '.'));
    final n = note.text.trim();
    ctrl.dispose();
    note.dispose();
    if (ok != true || !mounted) return;
    await runAction(context, () => ref.read(repoProvider).submitTask(widget.id, completedQuantity: q, note: n), success: 'Tekshiruvga yuborildi');
    ref.invalidate(myTaskProvider(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(myTaskProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Vazifa')),
      body: AsyncBody(
        value: task,
        onRetry: () => ref.invalidate(myTaskProvider(widget.id)),
        builder: (t) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: Text(t.title, style: Theme.of(context).textTheme.titleLarge)),
              Pill(taskStatusLabel(t.status), color: taskStatusColor(t.status)),
            ]),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  if (t.quantity != null) InfoRow(S.quantity, qty(t.quantity, t.unit)),
                  if (t.completedQuantity != null) InfoRow(S.completedQuantity, qty(t.completedQuantity, t.unit)),
                  if (t.siteName != null) InfoRow('Obyekt', t.siteName!),
                  if (t.dueDate != null) InfoRow(S.dueDate, fmtDate(t.dueDate)),
                ]),
              ),
            ),
            if (t.description != null) ...[const SectionTitle(S.description), Text(t.description!)],
            if (t.approvals.isNotEmpty) ...[
              const SectionTitle('Prorab javobi'),
              for (final a in t.approvals.reversed)
                Card(
                  child: ListTile(
                    leading: Icon(a.decision == 'APPROVED' ? Icons.verified : Icons.feedback_outlined, color: a.decision == 'APPROVED' ? AppColors.verified : AppColors.danger),
                    title: Text(a.decision == 'APPROVED' ? 'Tasdiqlandi' : (a.decision == 'REJECTED' ? 'Rad etildi' : "Qayta ishlash so'raldi")),
                    subtitle: Text([a.comment, fmtDateTime(a.createdAt)].whereType<String>().join('\n')),
                  ),
                ),
            ],
            SectionTitle(S.evidence, trailing: _uploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null),
            EvidenceGrid(evidence: t.evidence),
            if (t.isWorkable) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _uploading ? null : () => _addPhoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text(S.takePhoto))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _uploading ? null : () => _addPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text(S.fromGallery))),
              ]),
              const SizedBox(height: 20),
              if (t.status == 'ASSIGNED' || t.status == 'CHANGES_REQUESTED')
                OutlinedButton(
                  onPressed: () async {
                    await runAction(context, () => ref.read(repoProvider).startTask(widget.id));
                    ref.invalidate(myTaskProvider(widget.id));
                  },
                  child: const Text(S.startTask),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: _uploading ? null : () => _submit(t), icon: const Icon(Icons.send_rounded), label: const Text(S.submitTask)),
            ],
          ],
        ),
      ),
    );
  }
}
