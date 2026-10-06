import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/generated/export.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeServer implements HttpClientAdapter {
  FakeServer(this._respond);

  final ({int status, Object? body}) Function(RequestOptions) _respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _respond(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio buildDio(
  FakeServer server, {
  String? token,
  void Function()? onUnauthorized,
}) {
  return createApiDio(
    baseUrl: 'http://api.test',
    readToken: () async => token,
    onUnauthorized: onUnauthorized ?? () {},
    adapter: server,
  );
}

Map<String, Object?> entryJson({int id = 1}) => {
  'id': id,
  'title': 'Hades',
  'genre': ['Roguelike'],
  'platform': ['PC'],
  'status': 'Backlog',
  'owned': true,
  'interest': 3,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-02T00:00:00Z',
  'steam_app_id': 1145360,
};

void main() {
  group('createApiDio', () {
    test('sends the stored token as a Bearer header', () async {
      final server = FakeServer((_) => (status: 200, body: <Object?>[]));
      final client = RestClient(buildDio(server, token: 'abc123'));

      await client.fallback.apiBacklogEntriesListEntries();

      expect(server.requests.single.headers['Authorization'], 'Bearer abc123');
    });

    test('sends no Authorization header without a token', () async {
      final server = FakeServer((_) => (status: 200, body: <Object?>[]));
      final client = RestClient(buildDio(server));

      await client.fallback.apiBacklogEntriesListEntries();

      expect(server.requests.single.headers['Authorization'], isNull);
    });

    test('calls onUnauthorized on a 401 and still throws', () async {
      var logouts = 0;
      final server = FakeServer(
        (_) => (status: 401, body: {'detail': 'Not authenticated'}),
      );
      final client = RestClient(
        buildDio(server, token: 'stale', onUnauthorized: () => logouts++),
      );

      await expectLater(
        client.fallback.apiBacklogEntriesListEntries(),
        throwsA(isA<DioException>()),
      );
      expect(logouts, 1);
    });

    test(
      'ignores a 401 for a token that is no longer the session token',
      () async {
        var logouts = 0;
        var current = 'old';
        late final Dio dio;
        final server = FakeServer((_) {
          current = 'new';
          return (status: 401, body: {'detail': 'Not authenticated'});
        });
        dio = createApiDio(
          baseUrl: 'http://api.test',
          readToken: () => current,
          onUnauthorized: () => logouts++,
          adapter: server,
        );

        await expectLater(
          RestClient(dio).fallback.apiBacklogEntriesListEntries(),
          throwsA(isA<DioException>()),
        );
        expect(logouts, 0);
      },
    );

    test(
      'still throws the original error when reading the token fails',
      () async {
        var reads = 0;
        var logouts = 0;
        final server = FakeServer(
          (_) => (status: 401, body: {'detail': 'Not authenticated'}),
        );
        final dio = createApiDio(
          baseUrl: 'http://api.test',
          readToken: () =>
              ++reads == 1 ? 'token' : throw StateError('keychain'),
          onUnauthorized: () => logouts++,
          adapter: server,
        );

        await expectLater(
          RestClient(dio).fallback.apiBacklogEntriesListEntries(),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              401,
            ),
          ),
        );
        expect(logouts, 0);
      },
    );

    test('does not call onUnauthorized for other errors', () async {
      var logouts = 0;
      final server = FakeServer((_) => (status: 500, body: {'detail': 'boom'}));
      final client = RestClient(
        buildDio(server, token: 't', onUnauthorized: () => logouts++),
      );

      await expectLater(
        client.fallback.apiBacklogEntriesListEntries(),
        throwsA(isA<DioException>()),
      );
      expect(logouts, 0);
    });

    test('maps a login response to the typed result', () async {
      final server = FakeServer(
        (_) =>
            (status: 201, body: {'access_token': 'jwt', 'requires_2fa': false}),
      );
      final client = RestClient(buildDio(server));

      final result = await client.fallback.apiAuthLoginLogin(
        body: const LoginParams(email: 'a@b.de', password: 'secret'),
      );

      expect(result.accessToken, 'jwt');
      expect(result.requires2fa, isFalse);
      expect(server.requests.single.path, '/api/auth/login');
    });

    test('maps an entry list with snake_case fields', () async {
      final server = FakeServer(
        (_) => (status: 200, body: [entryJson(), entryJson(id: 2)]),
      );
      final client = RestClient(buildDio(server, token: 't'));

      final entries = await client.fallback.apiBacklogEntriesListEntries();

      expect(entries.map((e) => e.id), [1, 2]);
      expect(entries.first.steamAppId, 1145360);
      expect(entries.first.createdAt, DateTime.utc(2026, 1, 1));
    });
  });

  group('ApiException.from', () {
    Future<Object> failWith(int status, Object? body) async {
      final client = RestClient(
        buildDio(FakeServer((_) => (status: status, body: body))),
      );
      try {
        await client.fallback.apiBacklogEntriesListEntries();
      } catch (error) {
        return error;
      }
      fail('expected the request to fail');
    }

    test('uses the detail of the backend error body', () async {
      final error = await failWith(409, {
        'status_code': 409,
        'detail': 'Entry already exists',
      });

      final exception = ApiException.from(error, 'fallback');

      expect(exception.message, 'Entry already exists');
      expect(exception.statusCode, 409);
    });

    test('falls back when the body has no detail', () async {
      final error = await failWith(500, {'status_code': 500});

      final exception = ApiException.from(error, 'Could not load entries');

      expect(exception.message, 'Could not load entries');
      expect(exception.statusCode, 500);
    });

    test('falls back for an empty detail', () async {
      final error = await failWith(400, {'detail': ''});

      expect(ApiException.from(error, 'fallback').message, 'fallback');
    });

    test('falls back for errors that are not HTTP responses', () {
      final exception = ApiException.from(StateError('x'), 'Offline');

      expect(exception.message, 'Offline');
      expect(exception.statusCode, isNull);
    });
  });
}
