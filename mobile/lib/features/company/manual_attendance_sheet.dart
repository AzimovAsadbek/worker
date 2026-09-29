import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import 'company_providers.dart';

/// No phone / broken phone: the foreman records the event on the worker's behalf (flagged MANUAL_ENTRY).
Future<void> showManualAttendance(BuildContext context, WidgetRef ref, {required String workerId, required String workerName, required String siteId, required bool working}) async {
  final type = working ? 'WORK_ENDED' : 'WORK_STARTED';
  var time = TimeOfDay.now();
  final reason = TextEditingController(text: "Ishchining telefoni yo'q");
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text('$workerName: ${working ? 'ishni yakunlash' : 'ishni boshlash'}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text('Vaqt: ${time.format(c)}'),
            onPressed: () async {
              final t = await showTimePicker(context: c, initialTime: time);
              if (t != null) setState(() => time = t);
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: reason, decoration: const InputDecoration(labelText: S.reason)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text(S.save)),
        ],
      ),
    ),
  );
  final text = reason.text.trim();
  reason.dispose();
  if (ok != true || !context.mounted) return;
  final now = DateTime.now();
  var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (at.isAfter(now)) at = at.subtract(const Duration(days: 1));
  await runAction(
    context,
    () => ref.read(repoProvider).manualAttendance(cidFrom(ref), workerId: workerId, siteId: siteId, type: type, occurredAt: at, reason: text.length < 3 ? "Qo'lda kiritildi" : text),
    success: 'Saqlandi',
  );
  ref.invalidate(dashboardProvider);
}
