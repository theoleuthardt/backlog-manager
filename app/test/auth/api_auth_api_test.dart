import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/auth_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeServer implements HttpClientAdapter {
  FakeServer(this.respond);

  final ({int status, Object? body}) Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = respond(options);
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

ApiAuthApi apiFor(FakeServer server) {
  final dio = createApiDio(
    baseUrl: 'https://api.test',
    readToken: () async => null,
    onUnauthorized: () {},
    adapter: server,
  );
  return ApiAuthApi(() async => dio);
}

Map<String, Object?> userJson({bool setupCompleted = true}) => {
  'id': 1,
  'name': 'Theo',
  'email': 'theo@example.com',
  'is_admin': false,
  'is_two_factor_enabled': false,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
  'has_steam_api_key': false,
  'has_igdb_credentials': false,
  'has_steamgriddb_api_key': false,
  'has_discord_webhook_url': false,
  'steam_auto_import_enabled': false,
  'setup_completed': setupCompleted,
  'default_sort': 'status',
  'theme': 'dark',
};

void main() {
  group('login', () {
    test('posts the credentials and returns the access token', () async {
      final server = FakeServer(
        (_) =>
            (status: 201, body: {'access_token': 'jwt', 'requires_2fa': false}),
      );

      final outcome = await apiFor(server).login('theo@example.com', 'secret');

      expect(
        outcome,
        isA<LoginSucceeded>().having((o) => o.accessToken, 'token', 'jwt'),
      );
      expect(server.requests.single.path, '/api/auth/login');
      expect(server.requests.single.data, {
        'email': 'theo@example.com',
        'password': 'secret',
      });
    });

    test(
      'returns the challenge when the account needs a second factor',
      () async {
        final server = FakeServer(
          (_) => (
            status: 201,
            body: {'requires_2fa': true, 'challenge_token': 'c-1'},
          ),
        );

        final outcome = await apiFor(server).login('a@b.de', 'x');

        expect(
          outcome,
          isA<LoginNeedsTwoFactor>().having(
            (o) => o.challengeToken,
            'challenge',
            'c-1',
          ),
        );
      },
    );

    test('fails when the answer has no token and no challenge', () async {
      final server = FakeServer(
        (_) => (status: 201, body: {'requires_2fa': false}),
      );

      expect(apiFor(server).login('a@b.de', 'x'), throwsA(isA<ApiException>()));
    });

    test('lets the error of the backend through', () async {
      final server = FakeServer(
        (_) => (status: 401, body: {'detail': 'Invalid email or password'}),
      );

      await expectLater(
        apiFor(server).login('a@b.de', 'wrong'),
        throwsA(
          isA<DioException>().having(
            (e) => ApiException.from(e, 'Login failed').message,
            'message',
            'Invalid email or password',
          ),
        ),
      );
    });
  });

  test(
    'verifyLogin posts the challenge and the code and returns the token',
    () async {
      final server = FakeServer(
        (_) => (
          status: 201,
          body: {'access_token': 'jwt', 'token_type': 'bearer'},
        ),
      );

      final token = await apiFor(server).verifyLogin('c-1', '123456');

      expect(token, 'jwt');
      expect(server.requests.single.path, '/api/auth/2fa/login-verify');
      expect(server.requests.single.data, {
        'challenge_token': 'c-1',
        'code': '123456',
      });
    },
  );

  test(
    'currentUser maps the user of the backend to the session user',
    () async {
      final server = FakeServer(
        (_) => (status: 200, body: userJson(setupCompleted: false)),
      );

      final user = await apiFor(server).currentUser();

      expect(user.name, 'Theo');
      expect(user.email, 'theo@example.com');
      expect(user.setupCompleted, isFalse);
      expect(server.requests.single.path, '/api/user/me');
    },
  );
}
