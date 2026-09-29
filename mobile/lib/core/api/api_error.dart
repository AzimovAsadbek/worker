import 'package:dio/dio.dart';

import '../l10n/strings.dart';

enum ApiErrorKind { offline, timeout, server, client, auth, unknown }

/// A failure the UI can show directly: [message] is already a specific Uzbek sentence.
class ApiError implements Exception {
  ApiError({required this.kind, required this.code, required this.message, this.statusCode, this.details = const {}});

  final ApiErrorKind kind;
  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> details;

  /// No connectivity / DNS / timeout: the request may be retried later.
  bool get isNetwork => kind == ApiErrorKind.offline || kind == ApiErrorKind.timeout;

  /// Server-side outage (5xx) — transient as well.
  bool get isTransient => isNetwork || kind == ApiErrorKind.server;

  factory ApiError.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiError(kind: ApiErrorKind.timeout, code: 'TIMEOUT', message: S.timeout);
      case DioExceptionType.connectionError:
        return ApiError(kind: ApiErrorKind.offline, code: 'OFFLINE', message: S.offline);
      case DioExceptionType.badResponse:
        return ApiError.fromResponse(e.response);
      case DioExceptionType.cancel:
        return ApiError(kind: ApiErrorKind.unknown, code: 'CANCELLED', message: S.unknownError);
      case DioExceptionType.badCertificate:
        return ApiError(kind: ApiErrorKind.offline, code: 'BAD_CERTIFICATE', message: S.serverUnavailable);
      case DioExceptionType.unknown:
        if (e.error is ApiError) return e.error! as ApiError;
        // SocketException etc. surface here on some platforms
        return ApiError(kind: ApiErrorKind.offline, code: 'OFFLINE', message: S.offline);
    }
  }

  factory ApiError.fromResponse(Response<dynamic>? res) {
    final status = res?.statusCode ?? 0;
    final data = res?.data;
    String code = 'HTTP_$status';
    String? serverMessage;
    Map<String, dynamic> details = const {};
    if (data is Map<String, dynamic>) {
      if (data['code'] is String) code = data['code'] as String;
      if (data['message'] is String) serverMessage = data['message'] as String;
      if (data['details'] is Map<String, dynamic>) details = data['details'] as Map<String, dynamic>;
    }
    final kind = status >= 500
        ? ApiErrorKind.server
        : status == 401
            ? ApiErrorKind.auth
            : ApiErrorKind.client;
    if (status >= 500 && code.startsWith('HTTP_')) code = 'INTERNAL';
    return ApiError(
      kind: kind,
      code: code,
      statusCode: status,
      details: details,
      message: messageForCode(code, details: details, fallback: status >= 500 ? S.serverUnavailable : serverMessage),
    );
  }

  factory ApiError.unknown(Object e) => ApiError(kind: ApiErrorKind.unknown, code: 'UNKNOWN', message: S.unknownError);

  static ApiError from(Object e) {
    if (e is ApiError) return e;
    if (e is DioException) return ApiError.fromDio(e);
    return ApiError.unknown(e);
  }

  @override
  String toString() => 'ApiError($code, $statusCode)';
}
