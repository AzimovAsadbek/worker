import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/session.dart';
import 'auth/token_store.dart';
import 'db/database.dart';
import 'device/device_id.dart';
import 'location/location_service.dart';
import 'sync/sync_service.dart';

export 'api/api_client.dart' show Json;

Map<String, dynamic> decodeJson(String s) => jsonDecode(s) as Map<String, dynamic>;
String encodeJson(Object o) => jsonEncode(o);
String platformName() => kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
final deviceIdProvider = Provider<DeviceIdStore>((ref) => DeviceIdStore());
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokens: ref.watch(tokenStoreProvider),
    onSessionExpired: () => ref.read(sessionProvider.notifier).expired(),
  );
});

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Emits true when any network interface is up (not a guarantee the API is reachable).
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool up(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);
  yield up(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(up);
});

/// Bumped whenever the server state changed after a sync, so screens can refetch.
final serverRevisionProvider = NotifierProvider<RevisionCounter, int>(RevisionCounter.new);

class RevisionCounter extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

/// One outbox processor per logged-in user.
final syncServiceProvider = FutureProvider<SyncService?>((ref) async {
  final userId = ref.watch(sessionProvider.select((s) => s.me?.id));
  if (userId == null) return null;
  final service = SyncService(
    db: ref.read(databaseProvider),
    api: ref.read(apiProvider),
    userId: userId,
    deviceId: await ref.read(deviceIdProvider).get(),
    onServerStateChanged: () => ref.read(serverRevisionProvider.notifier).bump(),
  );
  await service.start();
  ref.listen(connectivityProvider, (prev, next) {
    if (next.value == true && prev?.value != true) unawaited(service.syncNow(force: true));
  });
  ref.onDispose(service.dispose);
  return service;
});

/// Live list of events not yet confirmed by the server (plus unacknowledged rejections).
final unsyncedEventsProvider = StreamProvider<List<PendingEvent>>((ref) {
  final userId = ref.watch(sessionProvider.select((s) => s.me?.id));
  if (userId == null) return Stream.value(const []);
  return ref.read(databaseProvider).watchUnsynced(userId);
});
