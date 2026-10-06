import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/api/server_url.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthAdapter implements HttpClientAdapter {
  HealthAdapter({this.status = 200, this.fail = false});

  final int status;
  final bool fail;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (fail) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'status': 'ok'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('parseServerUrl', () {
    test('accepts https for any host', () {
      expect(
        parseServerUrl('https://api.example.com'),
        isA<ServerUrlValid>().having(
          (r) => r.url,
          'url',
          'https://api.example.com',
        ),
      );
    });

    test('rejects plain http for a remote host', () {
      expect(parseServerUrl('http://api.example.com'), isA<ServerUrlInvalid>());
    });

    for (final url in [
      'http://localhost:8000',
      'http://127.0.0.1:8000',
      'http://[::1]:8000',
    ]) {
      test('allows loopback $url over http', () {
        expect(parseServerUrl(url), isA<ServerUrlValid>());
      });
    }

    for (final url in [
      'ftp://localhost:8000',
      'ws://127.0.0.1:8000',
      'file://localhost/x',
    ]) {
      test('rejects the non-http protocol of $url', () {
        expect(parseServerUrl(url), isA<ServerUrlInvalid>());
      });
    }

    for (final value in [
      'not a url',
      '',
      '   ',
      'https://',
      'api.example.com',
    ]) {
      test('rejects "$value"', () {
        expect(parseServerUrl(value), isA<ServerUrlInvalid>());
      });
    }

    test('trims whitespace and trailing slashes', () {
      expect(
        parseServerUrl('  https://api.example.com/  '),
        isA<ServerUrlValid>().having(
          (r) => r.url,
          'url',
          'https://api.example.com',
        ),
      );
    });

    test('keeps a path prefix', () {
      expect(
        parseServerUrl('https://example.com/backlog/'),
        isA<ServerUrlValid>().having(
          (r) => r.url,
          'url',
          'https://example.com/backlog',
        ),
      );
    });

    for (final url in [
      'https://api.example.com?x=1',
      'https://api.example.com/#top',
      'https://api.example.com/path?token=abc',
    ]) {
      test('rejects a query or fragment in $url', () {
        expect(parseServerUrl(url), isA<ServerUrlInvalid>());
      });
    }

    for (final url in [
      'https://api.example.com:99999',
      'https://api.example.com:0',
      'https://api.example.com:65536',
      'http://localhost:70000',
    ]) {
      test('rejects the out-of-range port of $url', () {
        expect(parseServerUrl(url), isA<ServerUrlInvalid>());
      });
    }

    for (final url in [
      'https://api.example.com:1',
      'https://api.example.com:65535',
      'http://localhost:8000',
    ]) {
      test('accepts the port of $url', () {
        expect(parseServerUrl(url), isA<ServerUrlValid>());
      });
    }

    test('rejects a non-ASCII host and asks for the punycode form', () {
      final result = parseServerUrl('https://exämple.com');

      expect(result, isA<ServerUrlInvalid>());
      expect((result as ServerUrlInvalid).message, contains('ASCII'));
    });

    test('accepts a host that is already written in punycode', () {
      expect(
        parseServerUrl('https://xn--exmple-cua.com'),
        isA<ServerUrlValid>(),
      );
    });

    for (final url in [
      'https://user:pass@api.example.com',
      'https://api.example.com:@8000',
      'https://token@api.example.com',
    ]) {
      test('rejects credentials in $url', () {
        expect(parseServerUrl(url), isA<ServerUrlInvalid>());
      });
    }

    test('explains why a remote http url is rejected', () {
      final result = parseServerUrl('http://api.example.com');

      expect((result as ServerUrlInvalid).message, contains('https'));
    });
  });

  group('defaultServerUrl', () {
    test('uses the build-time value', () {
      expect(
        resolveDefaultServerUrl(
          define: 'https://api.example.com',
          debug: false,
        ),
        'https://api.example.com',
      );
    });

    test('falls back to the local backend in debug builds', () {
      expect(
        resolveDefaultServerUrl(define: '', debug: true),
        'http://localhost:8000',
      );
    });

    test('has no default in a release build without a value', () {
      expect(resolveDefaultServerUrl(define: '', debug: false), isNull);
    });

    test('ignores an invalid build-time value', () {
      expect(
        resolveDefaultServerUrl(define: 'http://api.example.com', debug: false),
        isNull,
      );
    });
  });

  group('checkServerHealth', () {
    test('requests GET /health on the server', () async {
      final adapter = HealthAdapter();

      final result = await checkServerHealth(
        'https://api.example.com',
        adapter: adapter,
      );

      expect(result, isNull);
      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.com/health',
      );
    });

    test('reports an unreachable server', () async {
      final result = await checkServerHealth(
        'https://api.example.com',
        adapter: HealthAdapter(fail: true),
      );

      expect(result, contains('reach'));
    });

    test('reports an unhealthy server', () async {
      final result = await checkServerHealth(
        'https://api.example.com',
        adapter: HealthAdapter(status: 503),
      );

      expect(result, isNotNull);
    });
  });

  group('ServerUrlStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns the default until a url is saved', () async {
      final store = ServerUrlStore(defaultUrl: 'https://default.example.com');

      expect(await store.read(), 'https://default.example.com');
    });

    test('remembers a saved url', () async {
      await ServerUrlStore(defaultUrl: 'https://default.example.com')
          .write('https://mine.example.com');

      expect(
        await ServerUrlStore(defaultUrl: 'https://default.example.com').read(),
        'https://mine.example.com',
      );
    });

    test('is null without a default or a saved url', () async {
      expect(await ServerUrlStore(defaultUrl: null).read(), isNull);
    });
  });

  group('changeServer', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves a valid, reachable server and signs the user out', () async {
      final store = ServerUrlStore(defaultUrl: null);
      var signedOut = 0;

      final error = await changeServer(
        'https://mine.example.com/',
        store: store,
        adapter: HealthAdapter(),
        onChanged: () async => signedOut++,
      );

      expect(error, isNull);
      expect(await store.read(), 'https://mine.example.com');
      expect(signedOut, 1);
    });

    test('rejects an insecure url without saving or signing out', () async {
      final store = ServerUrlStore(defaultUrl: null);
      var signedOut = 0;

      final error = await changeServer(
        'http://api.example.com',
        store: store,
        adapter: HealthAdapter(),
        onChanged: () async => signedOut++,
      );

      expect(error, contains('https'));
      expect(await store.read(), isNull);
      expect(signedOut, 0);
    });

    test(
      'rejects an unreachable server without saving or signing out',
      () async {
        final store = ServerUrlStore(defaultUrl: null);
        var signedOut = 0;

        final error = await changeServer(
          'https://mine.example.com',
          store: store,
          adapter: HealthAdapter(fail: true),
          onChanged: () async => signedOut++,
        );

        expect(error, isNotNull);
        expect(await store.read(), isNull);
        expect(signedOut, 0);
      },
    );

    test('finishes the clean-up before the new url is saved', () async {
      final store = ServerUrlStore(defaultUrl: 'https://old.example.com');
      String? savedWhileCleaning;

      await changeServer(
        'https://mine.example.com',
        store: store,
        adapter: HealthAdapter(),
        onChanged: () async => savedWhileCleaning = await store.read(),
      );

      expect(savedWhileCleaning, 'https://old.example.com');
      expect(await store.read(), 'https://mine.example.com');
    });

    test('keeps the old server when the clean-up fails', () async {
      final store = ServerUrlStore(defaultUrl: 'https://old.example.com');

      await expectLater(
        changeServer(
          'https://mine.example.com',
          store: store,
          adapter: HealthAdapter(),
          onChanged: () async => throw StateError('sign-out failed'),
        ),
        throwsStateError,
      );

      expect(await store.read(), 'https://old.example.com');
    });

    test('does not sign out when the url did not change', () async {
      final store = ServerUrlStore(defaultUrl: 'https://mine.example.com');
      var signedOut = 0;

      final error = await changeServer(
        'https://mine.example.com',
        store: store,
        adapter: HealthAdapter(),
        onChanged: () async => signedOut++,
      );

      expect(error, isNull);
      expect(signedOut, 0);
    });
  });
}
