import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../api/api_error.dart';
import '../providers.dart';

enum SessionPhase { loading, loggedOut, ready }

/// "worker" or a supervisor membership id.
const workerContext = 'worker';

class SessionState {
  const SessionState({required this.phase, this.me, this.context = workerContext, this.isNewUser = false, this.offline = false});
  final SessionPhase phase;
  final Me? me;
  final String context;
  final bool isNewUser;
  /// Session restored from cache while the server was unreachable.
  final bool offline;

  Membership? get activeMembership {
    if (me == null || context == workerContext) return null;
    for (final m in me!.memberships) {
      if (m.id == context && m.isSupervisor) return m;
    }
    return null;
  }

  bool get inCompanyMode => activeMembership != null;

  SessionState copyWith({SessionPhase? phase, Me? me, String? context, bool? isNewUser, bool? offline}) => SessionState(
        phase: phase ?? this.phase,
        me: me ?? this.me,
        context: context ?? this.context,
        isNewUser: isNewUser ?? this.isNewUser,
        offline: offline ?? this.offline,
      );
}

class SessionController extends Notifier<SessionState> {
  static const _ctxKey = 'session.context';
  static const _meKey = 'session.me';

  @override
  SessionState build() {
    unawaited(_bootstrap());
    return const SessionState(phase: SessionPhase.loading);
  }

  Future<void> _bootstrap() async {
    final tokens = ref.read(tokenStoreProvider);
    await tokens.load();
    if (!tokens.hasSession) {
      state = const SessionState(phase: SessionPhase.loggedOut);
      return;
    }
    final db = ref.read(databaseProvider);
    final savedCtx = (await db.getCache(_ctxKey))?.json ?? workerContext;
    try {
      final me = await _fetchMe();
      state = SessionState(phase: SessionPhase.ready, me: me, context: _validContext(me, savedCtx));
    } on ApiError catch (e) {
      if (e.kind == ApiErrorKind.auth) {
        await _clearLocal();
        state = const SessionState(phase: SessionPhase.loggedOut);
        return;
      }
      // Offline start: use the last known profile so the worker can still check in.
      final cached = await db.getCache(_meKey);
      if (cached != null) {
        final me = Me.fromJson(decodeJson(cached.json));
        state = SessionState(phase: SessionPhase.ready, me: me, context: _validContext(me, savedCtx), offline: true);
      } else {
        state = const SessionState(phase: SessionPhase.loggedOut);
      }
    }
  }

  String _validContext(Me me, String ctx) {
    if (ctx == workerContext) {
      // Supervisors-only users land in their company by default.
      if (!me.isWorkerSomewhere && me.supervisorMemberships.isNotEmpty) return me.supervisorMemberships.first.id;
      return workerContext;
    }
    return me.memberships.any((m) => m.id == ctx && m.isSupervisor) ? ctx : workerContext;
  }

  Future<Me> _fetchMe() async {
    final json = await ref.read(apiProvider).get<Json>('/me');
    await ref.read(databaseProvider).putCache(_meKey, encodeJson(json));
    return Me.fromJson(json);
  }

  Future<Map<String, dynamic>> requestOtp(String phone) => ref.read(apiProvider).post<Json>('/auth/otp/request', body: {'phone': phone}, noAuth: true);

  Future<void> verifyOtp(String phone, String code) async {
    final device = await ref.read(deviceIdProvider).get();
    final res = await ref.read(apiProvider).post<Json>(
      '/auth/otp/verify',
      body: {'phone': phone, 'code': code, 'deviceId': device, 'platform': platformName()},
      noAuth: true,
    );
    await ref.read(tokenStoreProvider).save(access: res['accessToken'] as String, refresh: res['refreshToken'] as String);
    final meJson = res['me'] as Json;
    await ref.read(databaseProvider).putCache(_meKey, encodeJson(meJson));
    final me = Me.fromJson(meJson);
    state = SessionState(phase: SessionPhase.ready, me: me, context: _validContext(me, workerContext), isNewUser: res['isNewUser'] == true);
  }

  Future<void> refreshMe() async {
    final me = await _fetchMe();
    state = state.copyWith(me: me, context: _validContext(me, state.context), offline: false);
  }

  Future<void> updateName(String fullName) async {
    final json = await ref.read(apiProvider).patch<Json>('/me', body: {'fullName': fullName});
    await ref.read(databaseProvider).putCache(_meKey, encodeJson(json));
    state = state.copyWith(me: Me.fromJson(json));
  }

  Future<void> switchContext(String ctx) async {
    await ref.read(databaseProvider).putCache(_ctxKey, ctx);
    state = state.copyWith(context: ctx, isNewUser: false);
  }

  void finishOnboarding() => state = state.copyWith(isNewUser: false);

  /// Server logout (best effort) + local wipe. Pending outbox rows stay tied to the user id.
  Future<void> logout() async {
    try {
      await ref.read(apiProvider).post<void>('/auth/logout');
    } catch (_) {}
    await _clearLocal();
    state = const SessionState(phase: SessionPhase.loggedOut);
  }

  /// Called by the API client when the refresh token is definitively rejected.
  Future<void> expired() async {
    if (state.phase == SessionPhase.loggedOut) return;
    await _clearLocal();
    state = const SessionState(phase: SessionPhase.loggedOut);
  }

  Future<void> _clearLocal() async {
    await ref.read(tokenStoreProvider).clear();
    await ref.read(databaseProvider).clearCache();
  }
}
