import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Offline outbox for attendance events. A row is written BEFORE any network call, so a tap is
/// never lost (no internet, app killed, phone restarted). The server is idempotent on clientEventId.
@DataClassName('PendingEvent')
class PendingEvents extends Table {
  TextColumn get clientEventId => text()();
  TextColumn get userId => text()(); // owner — never sync another user's events after re-login
  TextColumn get type => text()(); // WORK_STARTED | WORK_ENDED
  TextColumn get siteId => text()();
  TextColumn get siteName => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  BoolColumn get isMocked => boolean().nullable()();
  TextColumn get deviceId => text()();
  TextColumn get status => text()(); // PENDING | SYNCING | SYNCED | REJECTED
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get serverShiftId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get acknowledged => boolean().withDefault(const Constant(false))(); // user saw the rejection

  @override
  Set<Column<Object>> get primaryKey => {clientEventId};
}

/// Last known server responses (Today, sites) so the worker app opens instantly offline.
@DataClassName('CacheEntry')
class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [PendingEvents, CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'worker_os'));

  @override
  int get schemaVersion => 1;

  // ───── outbox ─────

  Future<void> enqueue(PendingEventsCompanion e) => into(pendingEvents).insert(e);

  /// Events that still need to reach the server, oldest first.
  Future<List<PendingEvent>> dueEvents(String userId, DateTime now) {
    return (select(pendingEvents)
          ..where((t) => t.userId.equals(userId) & t.status.equals('PENDING') & (t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now)))
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
  }

  Stream<List<PendingEvent>> watchUnsynced(String userId) {
    return (select(pendingEvents)
          ..where((t) => t.userId.equals(userId) & (t.status.isIn(['PENDING', 'SYNCING']) | (t.status.equals('REJECTED') & t.acknowledged.equals(false))))
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .watch();
  }

  Future<List<PendingEvent>> unsynced(String userId) {
    return (select(pendingEvents)..where((t) => t.userId.equals(userId) & t.status.isIn(['PENDING', 'SYNCING']))).get();
  }

  Future<void> setStatus(List<String> ids, String status) =>
      (update(pendingEvents)..where((t) => t.clientEventId.isIn(ids))).write(PendingEventsCompanion(status: Value(status)));

  Future<void> markSynced(String id, {String? shiftId}) => (update(pendingEvents)..where((t) => t.clientEventId.equals(id))).write(
        PendingEventsCompanion(status: const Value('SYNCED'), syncedAt: Value(DateTime.now()), serverShiftId: Value(shiftId), errorCode: const Value(null), errorMessage: const Value(null)),
      );

  Future<void> markRejected(String id, String code, String message) => (update(pendingEvents)..where((t) => t.clientEventId.equals(id))).write(
        PendingEventsCompanion(status: const Value('REJECTED'), errorCode: Value(code), errorMessage: Value(message), syncedAt: Value(DateTime.now())),
      );

  Future<void> markRetry(String id, int attempts, DateTime next, String? code, String? message) =>
      (update(pendingEvents)..where((t) => t.clientEventId.equals(id))).write(
        PendingEventsCompanion(status: const Value('PENDING'), attempts: Value(attempts), nextAttemptAt: Value(next), errorCode: Value(code), errorMessage: Value(message)),
      );

  Future<void> acknowledge(String id) =>
      (update(pendingEvents)..where((t) => t.clientEventId.equals(id))).write(const PendingEventsCompanion(acknowledged: Value(true)));

  /// A crash during sync leaves rows in SYNCING; they are safe to resend (idempotent server).
  Future<int> resetStuck() => (update(pendingEvents)..where((t) => t.status.equals('SYNCING'))).write(const PendingEventsCompanion(status: Value('PENDING')));

  /// Keep the outbox small: synced rows older than 7 days are not needed any more.
  Future<int> pruneSynced() => (delete(pendingEvents)
        ..where((t) => t.status.equals('SYNCED') & t.syncedAt.isSmallerThanValue(DateTime.now().subtract(const Duration(days: 7)))))
      .go();

  // ───── cache ─────

  Future<void> putCache(String key, String json) =>
      into(cacheEntries).insertOnConflictUpdate(CacheEntriesCompanion.insert(key: key, json: json, updatedAt: DateTime.now()));

  Future<CacheEntry?> getCache(String key) => (select(cacheEntries)..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<void> clearCache() => delete(cacheEntries).go();
}
