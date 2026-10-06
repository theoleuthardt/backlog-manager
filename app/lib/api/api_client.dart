import 'dart:async';

import 'package:dio/dio.dart';

/// Builds the [Dio] instance every generated client call goes through.
///
/// [readToken] supplies the stored Bearer token for each request. A 401 always
/// means the token is no longer valid (expired, the user was deleted or, for a
/// login request, the credentials were wrong), so [onUnauthorized] is called
/// to clear the session and the error still reaches the caller.
Dio createApiDio({
  required String baseUrl,
  required FutureOr<String?> Function() readToken,
  required void Function() onUnauthorized,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) onUnauthorized();
        handler.next(error);
      },
    ),
  );
  return dio;
}
