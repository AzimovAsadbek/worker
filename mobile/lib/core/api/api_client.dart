import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config.dart';
import 'api_error.dart';

typedef Json = Map<String, dynamic>;

/// Thin JSON client. Adds the bearer token, transparently refreshes an expired access token
/// once (single-flight, so parallel 401s share one refresh), and converts failures to [ApiError].
class ApiClient {
  ApiClient({required this.tokens, required this.onSessionExpired, Dio? dio, String? baseUrl})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                sendTimeout: AppConfig.receiveTimeout,
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
              ),
            ) {
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final token = tokens.accessToken;
              if (token != null && options.extra['noAuth'] != true) options.headers['Authorization'] = 'Bearer $token';
              handler.next(options);
            },
            onError: _onError,
          ),
        );
  }

  final Dio dio;
  final TokenStore tokens;
  final Future<void> Function() onSessionExpired;
  Completer<bool>? _refreshing;

  Future<void> _onError(DioException e, ErrorInterceptorHandler handler) async {
    final res = e.response;
    final isAuthCall = e.requestOptions.path.startsWith('/auth/');
    final alreadyRetried = e.requestOptions.extra['retried'] == true;
    if (res?.statusCode != 401 || isAuthCall || alreadyRetried || tokens.refreshToken == null) {
      return handler.next(e);
    }
    final ok = await _refresh();
    if (!ok) {
      await onSessionExpired();
      return handler.next(e);
    }
    try {
      final opts = e.requestOptions
        ..extra['retried'] = true
        ..headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      final retry = await dio.fetch<dynamic>(opts);
      handler.resolve(retry);
    } on DioException catch (err) {
      handler.next(err);
    }
  }

  /// Returns false only when the server definitively refuses the refresh token.
  /// Network failures keep the session (the user may be offline on a construction site).
  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    final completer = _refreshing = Completer<bool>();
    try {
      final res = await dio.post<Json>(
        '/auth/refresh',
        data: {'refreshToken': tokens.refreshToken},
        options: Options(extra: {'noAuth': true}),
      );
      await tokens.save(access: res.data!['accessToken'] as String, refresh: res.data!['refreshToken'] as String);
      completer.complete(true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      completer.complete(!(status == 401 || status == 403));
    } catch (_) {
      completer.complete(false);
    } finally {
      _refreshing = null;
    }
    return completer.future;
  }

  Future<T> _wrap<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data as T;
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get<dynamic>(path, queryParameters: _clean(query)));
  Future<T> post<T>(String path, {Object? body, bool noAuth = false}) =>
      _wrap(() => dio.post<dynamic>(path, data: body ?? const <String, dynamic>{}, options: Options(extra: {'noAuth': noAuth})));
  Future<T> patch<T>(String path, {Object? body}) => _wrap(() => dio.patch<dynamic>(path, data: body));
  Future<T> put<T>(String path, {Object? body}) => _wrap(() => dio.put<dynamic>(path, data: body));
  Future<T> delete<T>(String path) => _wrap(() => dio.delete<dynamic>(path));

  Future<Json> upload(String path, {required String filePath, required String filename, Map<String, String> fields = const {}}) {
    return _wrap(() async {
      final form = FormData.fromMap({...fields, 'file': await MultipartFile.fromFile(filePath, filename: filename)});
      return dio.post<dynamic>(path, data: form, options: Options(contentType: 'multipart/form-data', sendTimeout: const Duration(seconds: 60)));
    });
  }

  /// Authenticated URL + headers for images (evidence).
  String url(String path) => '${dio.options.baseUrl}$path';
  Map<String, String> get authHeaders => {if (tokens.accessToken != null) 'Authorization': 'Bearer ${tokens.accessToken}'};

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    return Map.fromEntries(q.entries.where((e) => e.value != null && e.value != ''));
  }
}
