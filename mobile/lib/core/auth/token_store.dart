import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens live in the OS keystore (Android Keystore / iOS Keychain), cached in memory.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  String? _access;
  String? _refresh;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _access = await _storage.read(key: _kAccess);
    _refresh = await _storage.read(key: _kRefresh);
    _loaded = true;
  }

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null;

  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
