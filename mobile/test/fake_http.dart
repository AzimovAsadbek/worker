import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef Handler = FakeResponse Function(RequestOptions options, Object? body);

class FakeResponse {
  FakeResponse(this.status, this.body);
  final int status;
  final Object? body;
}

/// Offline simulation: throws a connection error for every request.
class OfflineError implements Exception {}

/// Minimal HTTP adapter so ApiClient runs its real interceptors and error mapping in tests.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  Handler handler;
  bool offline = false;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (offline) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    Object? body = options.data;
    if (body is String) body = jsonDecode(body);
    final r = handler(options, body);
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
