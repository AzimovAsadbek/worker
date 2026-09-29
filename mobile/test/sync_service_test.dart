import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_os/core/api/api_client.dart';
import 'package:worker_os/core/auth/token_store.dart';
import 'package:worker_os/core/db/database.dart';
import 'package:worker_os/core/sync/sync_service.dart';

import 'fake_http.dart';

class MemoryTokens extends TokenStore {
  MemoryTokens() : super();
  String? _a = 'access';
  String? _r = 'refresh';
  @override
  Future<void> load() async {}
  @override
  String? get accessToken => _a;
  @override
  String? get refreshToken => _r;
  @override
  Future<void> save({required String access, required String refresh}) async {
    _a = access;
    _r = refresh;
  }

  @override
  Future<void> clear() async => _a = _r = null;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late FakeAdapter adapter;
  late SyncService sync;
  late int serverChanges;

  /// Server stub: first WORK_STARTED accepted, later duplicates reported as DUPLICATE,
  /// a second WORK_STARTED rejected with ALREADY_CHECKED_IN.
  final accepted = <String>{};
  FakeResponse server(RequestOptions o, Object? body) {
    if (o.path != '/work-events/sync') return FakeResponse(404, {'code': 'NOT_FOUND'});
    final events = ((body as Map<String, dynamic>)['events'] as List).cast<Map<String, dynamic>>();
    final results = <Map<String, dynamic>>[];
    for (final e in events) {
      final id = e['clientEventId'] as String;
      if (accepted.contains(id)) {
        results.add({'clientEventId': id, 'status': 'DUPLICATE', 'shift': {'id': 'shift-1'}});
      } else if (e['type'] == 'WORK_STARTED' && accepted.isNotEmpty) {
        results.add({'clientEventId': id, 'status': 'REJECTED', 'code': 'ALREADY_CHECKED_IN', 'message': 'x'});
      } else {
        accepted.add(id);
        results.add({'clientEventId': id, 'status': 'ACCEPTED', 'shift': {'id': 'shift-1'}});
      }
    }
    return FakeResponse(200, {'results': results});
  }

  setUp(() async {
    accepted.clear();
    serverChanges = 0;
    db = AppDatabase(NativeDatabase.memory());
    adapter = FakeAdapter(server);
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter;
    final api = ApiClient(tokens: MemoryTokens(), onSessionExpired: () async {}, dio: dio);
    sync = SyncService(db: db, api: api, userId: 'user-1', deviceId: 'device-1', onServerStateChanged: () => serverChanges++);
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  test('online: event is stored first, then delivered and marked SYNCED', () async {
    final r = await sync.record(type: 'WORK_STARTED', siteId: 'site-1', latitude: 41, longitude: 71, accuracy: 10);
    expect(r.outcome, DeliveryOutcome.accepted);
    final rows = await db.select(db.pendingEvents).get();
    expect(rows.single.status, 'SYNCED');
    expect(rows.single.serverShiftId, 'shift-1');
    expect(serverChanges, 1);
    final sent = adapter.requests.single.data as Map<String, dynamic>;
    expect(((sent['events'] as List).single as Map<String, dynamic>)['deviceId'], 'device-1');
  });

  test('offline: tap is never lost; it is queued with backoff and delivered later exactly once', () async {
    adapter.offline = true;
    final r = await sync.record(type: 'WORK_STARTED', siteId: 'site-1');
    expect(r.outcome, DeliveryOutcome.queuedOffline);
    var row = (await db.select(db.pendingEvents).get()).single;
    expect(row.status, 'PENDING');
    expect(row.attempts, 1);
    expect(row.nextAttemptAt!.isAfter(DateTime.now()), isTrue);
    expect(await db.unsynced('user-1'), hasLength(1));

    // Backoff respected: not due yet → no request.
    adapter.offline = false;
    final before = adapter.requests.length;
    await sync.syncNow();
    expect(adapter.requests.length, before);

    // Internet is back and the retry time has come.
    await db.update(db.pendingEvents).write(const PendingEventsCompanion(nextAttemptAt: Value(null)));
    await sync.syncNow();
    row = (await db.select(db.pendingEvents).get()).single;
    expect(row.status, 'SYNCED');
    await sync.syncNow(); // nothing left
    expect(accepted.length, 1);
  });

  test('app killed during sync: SYNCING rows are reset and re-sent; server dedupes (DUPLICATE → SYNCED)', () async {
    await sync.record(type: 'WORK_STARTED', siteId: 'site-1');
    final id = (await db.select(db.pendingEvents).get()).single.clientEventId;
    await db.setStatus([id], 'SYNCING'); // simulate crash after sending
    expect(await db.resetStuck(), 1);
    await sync.syncNow();
    final row = (await db.select(db.pendingEvents).get()).single;
    expect(row.status, 'SYNCED');
    expect(accepted.length, 1);
  });

  test('business rejection is surfaced with a specific Uzbek message and not retried', () async {
    await sync.record(type: 'WORK_STARTED', siteId: 'site-1');
    final r = await sync.record(type: 'WORK_STARTED', siteId: 'site-1');
    expect(r.outcome, DeliveryOutcome.rejected);
    expect(r.code, 'ALREADY_CHECKED_IN');
    expect(r.message, contains('allaqachon'));
    final rejected = (await db.select(db.pendingEvents).get()).where((e) => e.status == 'REJECTED').single;
    expect(rejected.errorCode, 'ALREADY_CHECKED_IN');
    final before = adapter.requests.length;
    await sync.syncNow();
    expect(adapter.requests.length, before, reason: 'rejected events must not be resent');
  });

  test('offline start + end are delivered in chronological order in one batch', () async {
    adapter.offline = true;
    await sync.record(type: 'WORK_STARTED', siteId: 'site-1', occurredAt: DateTime.now().subtract(const Duration(hours: 8)));
    await sync.record(type: 'WORK_ENDED', siteId: 'site-1', occurredAt: DateTime.now().subtract(const Duration(minutes: 5)));
    adapter.offline = false;
    await db.update(db.pendingEvents).write(const PendingEventsCompanion(nextAttemptAt: Value(null)));
    await sync.syncNow();
    final last = adapter.requests.last.data as Map<String, dynamic>;
    expect((last['events'] as List).map((e) => (e as Map)['type']), ['WORK_STARTED', 'WORK_ENDED']);
    expect((await db.select(db.pendingEvents).get()).every((e) => e.status == 'SYNCED'), isTrue);
  });

  test("another user's queued events are never sent with this session", () async {
    await db.enqueue(PendingEventsCompanion.insert(
      clientEventId: 'other-user-event',
      userId: 'user-2',
      type: 'WORK_STARTED',
      siteId: 'site-1',
      occurredAt: DateTime.now(),
      deviceId: 'device-1',
      status: 'PENDING',
      createdAt: DateTime.now(),
    ));
    await sync.syncNow();
    expect(adapter.requests, isEmpty);
  });

  test('backoff grows and is capped at 5 minutes', () {
    expect(SyncService.backoff(1), const Duration(seconds: 5));
    expect(SyncService.backoff(2), const Duration(seconds: 10));
    expect(SyncService.backoff(4), const Duration(seconds: 40));
    expect(SyncService.backoff(20), const Duration(minutes: 5));
  });
}
