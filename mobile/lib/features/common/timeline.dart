import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';

/// Immutable event history of a shift: who did what, when, from where.
class EventTimeline extends StatelessWidget {
  const EventTimeline({super.key, required this.events, this.showLocation = false});
  final List<WorkEventView> events;
  final bool showLocation;

  IconData _icon(String t) => switch (t) {
        'WORK_STARTED' => Icons.play_circle_fill_rounded,
        'WORK_ENDED' => Icons.stop_circle_rounded,
        'SHIFT_VERIFIED' => Icons.verified_rounded,
        'SHIFT_REJECTED' => Icons.cancel_rounded,
        'SHIFT_CORRECTED' => Icons.edit_calendar_rounded,
        'SHIFT_AUTO_CLOSED' => Icons.timer_off_rounded,
        'DISPUTE_OPENED' || 'DISPUTE_RESOLVED' => Icons.gavel_rounded,
        _ => Icons.circle,
      };

  Color _color(String t) => switch (t) {
        'WORK_STARTED' => AppColors.start,
        'WORK_ENDED' => AppColors.end,
        'SHIFT_VERIFIED' => AppColors.verified,
        'SHIFT_REJECTED' || 'SHIFT_AUTO_CLOSED' => AppColors.danger,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const Text('—');
    return Card(
      child: Column(children: [
        for (final e in events)
          ListTile(
            leading: Icon(_icon(e.type), color: _color(e.type)),
            title: Text(eventTypeLabel(e.type), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${fmtDateTime(e.occurredAt)}${e.actorName != null ? ' · ${e.actorName}' : ''}'),
              if (e.receivedAt != null && e.receivedAt!.difference(e.occurredAt).inMinutes.abs() > 30)
                Text('Serverga yetib keldi: ${fmtDateTime(e.receivedAt)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              if (e.reason != null) Text(e.reason!, style: const TextStyle(fontStyle: FontStyle.italic)),
              if (showLocation && e.distanceMeters != null)
                Text(
                  "Obyektdan ${e.distanceMeters!.round()} m${e.accuracy != null ? ' (±${e.accuracy!.round()} m)' : ''}${e.insideGeofence == false ? ' — hududdan tashqarida' : ''}",
                  style: TextStyle(color: e.insideGeofence == false ? AppColors.danger : AppColors.muted, fontSize: 13),
                ),
              if (e.flags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 4, runSpacing: 4, children: [for (final f in e.flags) Pill(flagLabel(f), color: AppColors.warning)]),
                ),
            ]),
          ),
      ]),
    );
  }
}
