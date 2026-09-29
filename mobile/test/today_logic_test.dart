import 'package:flutter_test/flutter_test.dart';
import 'package:worker_os/core/db/database.dart';
import 'package:worker_os/features/worker/today_screen.dart';
import 'package:worker_os/models/models.dart';

PendingEvent pe(String type, DateTime at, {String status = 'PENDING'}) => PendingEvent(
      clientEventId: '$type-${at.millisecondsSinceEpoch}',
      userId: 'u',
      type: type,
      siteId: 'site-1',
      occurredAt: at,
      deviceId: 'd',
      status: status,
      attempts: 0,
      createdAt: at,
      acknowledged: false,
    );

TodayData today({Map<String, dynamic>? open, List<Map<String, dynamic>> shifts = const []}) => TodayData.fromJson({
      'date': '2026-09-30',
      'assignments': [
        {
          'assignmentId': 'a1',
          'isResident': false,
          'site': {'id': 'site-1', 'name': 'Blok A', 'latitude': 41.0, 'longitude': 71.6, 'radiusMeters': 200, 'shiftStart': '08:00', 'shiftEnd': '18:00'},
          'company': {'id': 'c1', 'name': 'Taraqqiyot'},
        },
      ],
      'openShift': open,
      'todayShifts': shifts,
      'openTasks': 0,
    });

void main() {
  final t0 = DateTime(2026, 9, 30, 8, 5);

  test('nothing yet → not started', () {
    expect(deriveToday(today(), const []).phase, WorkPhase.notStarted);
  });

  test('offline tap on START shows "working" immediately, marked pending', () {
    final e = deriveToday(today(), [pe('WORK_STARTED', t0)]);
    expect(e.phase, WorkPhase.working);
    expect(e.pending, isTrue);
    expect(e.since, t0);
  });

  test('offline START then END → finished (pending)', () {
    final e = deriveToday(today(), [pe('WORK_STARTED', t0), pe('WORK_ENDED', t0.add(const Duration(hours: 9)))]);
    expect(e.phase, WorkPhase.finished);
    expect(e.pending, isTrue);
  });

  test('server open shift → working', () {
    final e = deriveToday(today(open: {'id': 's1', 'siteId': 'site-1', 'status': 'OPEN', 'startedAt': t0.toUtc().toIso8601String()}), const []);
    expect(e.phase, WorkPhase.working);
    expect(e.pending, isFalse);
  });

  test("yesterday's forgotten shift (stale) does not block starting today and is flagged", () {
    final e = deriveToday(
      today(open: {'id': 's0', 'siteId': 'site-1', 'status': 'OPEN', 'isStale': true, 'startedAt': t0.subtract(const Duration(days: 1)).toUtc().toIso8601String()}),
      const [],
    );
    expect(e.phase, WorkPhase.notStarted);
    expect(e.staleOpenShift, isNotNull);
  });

  test('rejected local events do not change the displayed state', () {
    final e = deriveToday(today(), [pe('WORK_STARTED', t0, status: 'REJECTED')]);
    expect(e.phase, WorkPhase.notStarted);
  });

  test('ended shift today → finished', () {
    final e = deriveToday(
      today(shifts: [
        {'id': 's1', 'siteId': 'site-1', 'status': 'CLOSED', 'startedAt': t0.toUtc().toIso8601String(), 'endedAt': t0.add(const Duration(hours: 9)).toUtc().toIso8601String()},
      ]),
      const [],
    );
    expect(e.phase, WorkPhase.finished);
  });
}
