import 'dart:async';

import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/server_url.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The HTTP adapter the health check of a new server uses; tests replace it.
final serverHealthAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

final serverUrlStoreProvider = Provider<ServerUrlStore>(
  (ref) => ServerUrlStore(defaultUrl: defaultServerUrl),
);

/// The API client of the app: the server the user chose, the Bearer token of
/// the session and the rule that a 401 ends the session. It is created again
/// (`ref.invalidate`) when the server changes.
final apiDioProvider = FutureProvider<Dio>((ref) async {
  final baseUrl = await ref.watch(serverUrlStoreProvider).read();
  if (baseUrl == null) throw const ApiException('Choose a server first');
  return createApiDio(
    baseUrl: baseUrl,
    readToken: ref.read(tokenStoreProvider).read,
    onUnauthorized: () =>
        unawaited(ref.read(authControllerProvider.notifier).sessionExpired()),
  );
});

/// The server the app talks to, or null when none is set yet.
final serverUrlProvider = FutureProvider<String?>(
  (ref) => ref.watch(serverUrlStoreProvider).read(),
);
