import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};
const _debugServerUrl = 'http://localhost:8000';
const _storageKey = 'server_url';

/// Server URL baked into the build with `--dart-define=API_URL=...`.
const buildServerUrl = String.fromEnvironment('API_URL');

/// Outcome of validating a backend base URL typed by the user or set at build
/// time.
sealed class ServerUrlResult {
  const ServerUrlResult();
}

class ServerUrlValid extends ServerUrlResult {
  const ServerUrlValid(this.url);

  final String url;
}

class ServerUrlInvalid extends ServerUrlResult {
  const ServerUrlInvalid(this.message);

  final String message;
}

/// Validates a backend base URL: `https` for any host, `http` only for
/// loopback hosts (otherwise the Bearer token travels in cleartext), no other
/// protocol, no query or fragment. Surrounding whitespace and trailing slashes are dropped.
ServerUrlResult parseServerUrl(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const ServerUrlInvalid(
      'Enter a full server address, for example https://api.example.com',
    );
  }
  if (uri.hasQuery || uri.hasFragment) {
    return const ServerUrlInvalid(
      'The server address must not contain a query or a fragment',
    );
  }
  final loopback = _loopbackHosts.contains(uri.host);
  final allowed = uri.scheme == 'https' || (uri.scheme == 'http' && loopback);
  if (!allowed) {
    return const ServerUrlInvalid(
      'The server must use https, or your sign-in travels in cleartext '
      '(localhost is exempt)',
    );
  }
  return ServerUrlValid(trimmed);
}

/// The server a fresh install talks to: the build-time [define], or the local
/// backend in a [debug] build. A release build without a valid [define] has
/// none, so the user has to enter one.
String? resolveDefaultServerUrl({required String define, required bool debug}) {
  if (define.isEmpty) return debug ? _debugServerUrl : null;
  final result = parseServerUrl(define);
  return result is ServerUrlValid ? result.url : null;
}

final defaultServerUrl = resolveDefaultServerUrl(
  define: buildServerUrl,
  debug: kDebugMode,
);

/// Asks `GET /health` of [url]; returns a user-facing message when the server
/// cannot be used, or null when it is healthy.
Future<String?> checkServerHealth(
  String url, {
  HttpClientAdapter? adapter,
}) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  try {
    await dio.get<Object?>('/health');
    return null;
  } on DioException catch (error) {
    if (error.response != null) {
      return 'The server answered with an error (${error.response!.statusCode}). '
          'Check the address.';
    }
    return 'Could not reach the server. Check the address and your connection.';
  } finally {
    dio.close();
  }
}

/// Persists the server the user picked; reads fall back to [defaultUrl].
class ServerUrlStore {
  ServerUrlStore({required this.defaultUrl});

  final String? defaultUrl;

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey) ?? defaultUrl;
  }

  Future<void> write(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, url);
  }
}

/// Points the app at another backend. Validates [raw], checks that the server
/// answers `/health` and only then saves it. When the server really changed,
/// [onChanged] runs first (and must finish) so the caller can sign the user
/// out and clear cached data; if it throws, the old server stays saved.
/// Returns a user-facing error message, or null on success.
Future<String?> changeServer(
  String raw, {
  required ServerUrlStore store,
  required Future<void> Function() onChanged,
  HttpClientAdapter? adapter,
}) async {
  final parsed = parseServerUrl(raw);
  if (parsed is ServerUrlInvalid) return parsed.message;
  final url = (parsed as ServerUrlValid).url;

  final unhealthy = await checkServerHealth(url, adapter: adapter);
  if (unhealthy != null) return unhealthy;

  final previous = await store.read();
  if (previous != url) await onChanged();
  await store.write(url);
  return null;
}
