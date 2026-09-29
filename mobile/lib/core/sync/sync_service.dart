import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../db/database.dart';
import '../l10n/strings.dart';

class SyncStatus {
  const SyncStatus({this.syncing = false, this.lastError, this.lastSyncedAt});
  final bool syncing;
  final String? lastError;
  final DateTime? lastSyncedAt;
}

/// Outcome of trying to deliver one freshly recorded event right away.
enum DeliveryOutcome { accepted, queuedOffline, rejected }

class Delivery {
  const Delivery(this.outcome, {this.code, this.message, this.details = const {}});
  final DeliveryOutcome outcome;
  final String? code;
  final String? message;
  final Map<String, dynamic> details;
}

/// Offline-first outbox processor.
///
/// PENDING → (SYNCING) → SYNCED | REJECTED; transient failures go back to PENDING with exponential
/// backoff (5 s … 5 min). Safe to call from anywhere, any number of times (single-flight).
class SyncService {
  SyncService({required this.db, required this.api, required this.userId, required this.deviceId, this.onServerStateChanged});

  final AppDatabase db;
  final ApiClient api;
  final String userId;
  final String deviceId;
  final VoidCallback? onServerStateChanged;

  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus();
  Future<void>? _running;
  Timer? _timer;
  final Map<String, Delivery> _results = {};

  Stream<SyncStatus> get status => _status.stream;
  SyncStatus get current => _current;

  void _emit(SyncStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  Future<void> start() async {
    await db.resetStuck();
    await db.pruneSynced();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(syncNow()));
    unawaited(syncNow());
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_status.close());
  }

  static Duration backoff(int attempts) => Duration(seconds: math.min(300, 5 * math.pow(2, math.max(0, attempts - 1)).toInt()));

  /// Records an attendance event locally (always succeeds), then tries to deliver it immediately.
  Future<Delivery> record({
    required String type,
    required String siteId,
    String? siteName,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool? isMocked,
    DateTime? occurredAt,
  }) async {
    final id = const Uuid().v4();
    await db.enqueue(
      PendingEventsCompanion.insert(
        clientEventId: id,
        userId: userId,
        type: type,
        siteId: siteId,
        siteName: Value(siteName),
        occurredAt: occurredAt ?? DateTime.now(),
        latitude: Value(latitude),
        longitude: Value(longitude),
        accuracy: Value(accuracy),
        isMocked: Value(isMocked),
        deviceId: deviceId,
        status: 'PENDING',
        createdAt: DateTime.now(),
      ),
    );
    await syncNow();
    // A sync that was already running did not include this event — run once more.
    if (!_results.containsKey(id)) await syncNow();
    return _results.remove(id) ?? const Delivery(DeliveryOutcome.queuedOffline, message: S.offlineSaved);
  }

  Future<void> syncNow() {
    return _running ??= _run().whenComplete(() => _running = null);
  }

  Future<void> _run() async {
    final due = await db.dueEvents(userId, DateTime.now());
    if (due.isEmpty) return;
    _emit(SyncStatus(syncing: true, lastSyncedAt: _current.lastSyncedAt));
    var changed = false;
    String? error;
    try {
      for (var i = 0; i < due.length; i += 20) {
        final batch = due.sublist(i, math.min(i + 20, due.length));
        await db.setStatus(batch.map((e) => e.clientEventId).toList(), 'SYNCING');
        final Json res;
        try {
          res = await api.post<Json>('/work-events/sync', body: {'events': batch.map(_toJson).toList()});
        } on ApiError catch (e) {
          for (final ev in batch) {
            if (e.isTransient || e.kind == ApiErrorKind.auth) {
              await db.markRetry(ev.clientEventId, ev.attempts + 1, DateTime.now().add(backoff(ev.attempts + 1)), e.code, e.message);
            } else {
              // 4xx validation of the batch itself: the event can never succeed as-is.
              await db.markRejected(ev.clientEventId, e.code, e.message);
              _results[ev.clientEventId] = Delivery(DeliveryOutcome.rejected, code: e.code, message: e.message, details: e.details);
            }
          }
          error = e.message;
          if (e.isTransient) break;
          continue;
        }
        final results = (res['results'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
        for (final r in results) {
          final id = r['clientEventId'] as String? ?? '';
          final status = r['status'] as String? ?? 'RETRY';
          final shiftId = (r['shift'] as Map<String, dynamic>?)?['id'] as String?;
          final code = r['code'] as String? ?? 'UNKNOWN';
          final details = r['details'] is Map<String, dynamic> ? r['details'] as Map<String, dynamic> : const <String, dynamic>{};
          final ev = batch.firstWhere((b) => b.clientEventId == id, orElse: () => batch.first);
          switch (status) {
            case 'ACCEPTED':
            case 'DUPLICATE':
              await db.markSynced(id, shiftId: shiftId);
              _results[id] = const Delivery(DeliveryOutcome.accepted);
              changed = true;
            case 'REJECTED':
              final message = messageForCode(code, details: details, fallback: r['message'] as String?);
              await db.markRejected(id, code, message);
              _results[id] = Delivery(DeliveryOutcome.rejected, code: code, message: message, details: details);
              changed = true;
            default:
              await db.markRetry(id, ev.attempts + 1, DateTime.now().add(backoff(ev.attempts + 1)), code, r['message'] as String?);
          }
        }
      }
    } catch (e) {
      error = S.unknownError;
      await db.resetStuck();
    } finally {
      _emit(SyncStatus(syncing: false, lastError: error, lastSyncedAt: error == null ? DateTime.now() : _current.lastSyncedAt));
      if (changed) onServerStateChanged?.call();
    }
  }

  static Json _toJson(PendingEvent e) => {
        'clientEventId': e.clientEventId,
        'type': e.type,
        'siteId': e.siteId,
        'occurredAt': e.occurredAt.toUtc().toIso8601String(),
        if (e.latitude != null) 'latitude': e.latitude,
        if (e.longitude != null) 'longitude': e.longitude,
        if (e.accuracy != null) 'accuracy': e.accuracy,
        if (e.isMocked != null) 'isMocked': e.isMocked,
        'deviceId': e.deviceId,
      };
}
