import 'dart:io';
import 'dart:typed_data';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/auth/sign_in_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Server implements HttpClientAdapter {
  _Server(this._respond);

  final Future<ResponseBody> Function(RequestOptions) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _respond(options);

  @override
  void close({bool force = false}) {}
}

final now = DateTime(2026, 10, 27, 8, 10, 23);
const host = 'blm.example.dev';

Future<Object> signInFailing(
  Future<ResponseBody> Function(RequestOptions) respond,
) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://$host'))
    ..httpClientAdapter = _Server(respond);
  try {
    await RestClient(dio).fallback.apiAuthLoginLogin(
      body: const LoginParams(email: 'theo@example.com', password: 'secret'),
    );
  } on Object catch (error) {
    return error;
  }
  fail('expected the sign-in to fail');
}

Future<ResponseBody> json(int status, String body) async =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Future<ResponseBody> html(
  int status, {
  Map<String, List<String>> headers = const {},
}) async => ResponseBody.fromString(
  '<html><body>error</body></html>',
  status,
  headers: {
    Headers.contentTypeHeader: ['text/html'],
    ...headers,
  },
);

const cloudflare = {
  'server': ['cloudflare'],
  'cf-ray': ['a510c229ed88e50a-TXL'],
};

Future<SignInFailure> failureFor(
  Future<ResponseBody> Function(RequestOptions) respond,
) async => describeSignInFailure(
  await signInFailing(respond),
  fallback: 'Login failed',
  now: now,
);

Matcher isFailure(String title, String? explanation, String? details) =>
    isA<SignInFailure>()
        .having((f) => f.title, 'title', title)
        .having((f) => f.explanation, 'explanation', explanation)
        .having((f) => f.details, 'details', details);

SocketException socket(String message, int errorCode, String osMessage) =>
    SocketException(message, osError: OSError(osMessage, errorCode));

const notReachable = 'Server not reachable';
const notBacklogManager = 'Not a Backlog Manager server';
const notBacklogManagerExplanation =
    'blm.example.dev answered, but it is not a Backlog Manager server. '
    'Check the server address.';
const noAnswerExplanation =
    'blm.example.dev is reachable, but the Backlog Manager behind it does '
    'not answer. Try again later.';
const secureFailed = 'The secure connection to blm.example.dev failed.';

void main() {
  group('answers of the backend', () {
    test('shows the detail of the backend as it is, without more', () async {
      expect(
        await failureFor(
          (_) => json(
            401,
            '{"status_code": 401, "detail": "Invalid email or password"}',
          ),
        ),
        isFailure('Invalid email or password', null, null),
      );
    });

    test('explains the rate limit instead of its detail', () async {
      expect(
        await failureFor(
          (_) =>
              json(429, '{"status_code": 429, "detail": "Too Many Requests"}'),
        ),
        isFailure(
          'Too many sign-in attempts',
          'Wait a minute and try again.',
          'HTTP 429 · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('an internal error of the backend without a detail', () async {
      expect(
        await failureFor((_) => json(500, '{"status_code": 500}')),
        isFailure(
          'Server error',
          'The server had a problem. Try again later.',
          'HTTP 500 · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('a refusal of the backend without a detail', () async {
      expect(
        await failureFor((_) => json(400, '{"status_code": 400}')),
        isFailure(
          'Sign-in refused',
          'The server refused the sign-in.',
          'HTTP 400 · blm.example.dev · 08:10:23',
        ),
      );
    });
  });

  group('the server in front of the backend', () {
    test('a Cloudflare error page while the backend is down', () async {
      expect(
        await failureFor((_) => html(530, headers: cloudflare)),
        isFailure(
          'Server does not answer',
          noAnswerExplanation,
          'HTTP 530 · blm.example.dev · '
              'Cloudflare Ray a510c229ed88e50a-TXL · 08:10:23',
        ),
      );
    });

    test('a bad gateway page of another proxy', () async {
      expect(
        await failureFor((_) => html(502)),
        isFailure(
          'Server does not answer',
          noAnswerExplanation,
          'HTTP 502 · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('a request blocked by the Cloudflare firewall', () async {
      expect(
        await failureFor((_) => html(403, headers: cloudflare)),
        isFailure(
          'Blocked by a firewall',
          'blm.example.dev blocked the sign-in at its firewall.',
          'HTTP 403 · blm.example.dev · '
              'Cloudflare Ray a510c229ed88e50a-TXL · 08:10:23',
        ),
      );
    });

    test('a server that does not know the sign-in route', () async {
      expect(
        await failureFor((_) => html(404)),
        isFailure(
          notBacklogManager,
          notBacklogManagerExplanation,
          'HTTP 404 · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('JSON of another kind than the backend answers', () async {
      final error = await signInFailing(
        (_) => json(200, '{"access_token": 5, "requires_2fa": false}'),
      );
      expect(error, isNot(isA<DioException>()));
      expect(
        describeSignInFailure(error, fallback: 'Login failed', now: now),
        isFailure(
          notBacklogManager,
          'The server answered, but it is not a Backlog Manager server. '
              'Check the server address.',
          'unexpected answer · 08:10:23',
        ),
      );
    });

    test('a web page instead of the backend', () async {
      expect(
        await failureFor((_) => html(200)),
        isFailure(
          notBacklogManager,
          notBacklogManagerExplanation,
          'unexpected answer · blm.example.dev · 08:10:23',
        ),
      );
    });
  });

  group('the connection', () {
    test('the address cannot be resolved', () async {
      expect(
        await failureFor(
          (_) => throw socket(
            "Failed host lookup: 'blm.example.dev'",
            8,
            'nodename nor servname provided, or not known',
          ),
        ),
        isFailure(
          'Server not found',
          'Could not find blm.example.dev. Check the server address and your '
              'internet connection.',
          'DNS lookup failed · blm.example.dev · 08:10:23',
        ),
      );
    });

    for (final (system, code) in [
      ('Linux', 111),
      ('macOS', 61),
      ('Windows', 10061),
    ]) {
      test('the connection is refused on $system', () async {
        expect(
          await failureFor(
            (_) => throw socket('Connection refused', code, 'refused'),
          ),
          isFailure(
            notReachable,
            'blm.example.dev refused the connection. The server may be down.',
            'connection refused · blm.example.dev · 08:10:23',
          ),
        );
      });
    }

    for (final (system, code) in [
      ('Linux', 101),
      ('macOS', 51),
      ('Windows', 10051),
    ]) {
      test('the network is unreachable on $system', () async {
        expect(
          await failureFor(
            (_) => throw socket('Network is unreachable', code, 'unreachable'),
          ),
          isFailure(
            'No internet connection',
            'This device has no network connection. Check your internet '
                'connection.',
            'network unreachable · blm.example.dev · 08:10:23',
          ),
        );
      });
    }

    test('the connection times out in Dio', () async {
      expect(
        await failureFor(
          (options) => throw DioException.connectionTimeout(
            timeout: const Duration(seconds: 8),
            requestOptions: options,
          ),
        ),
        isFailure(
          notReachable,
          'blm.example.dev did not answer in time. Check your internet '
              'connection.',
          'connect timeout · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('the connection times out in the operating system', () async {
      expect(
        await failureFor(
          (_) => throw socket('Connection timed out', 110, 'timed out'),
        ),
        isFailure(
          notReachable,
          'blm.example.dev did not answer in time. Check your internet '
              'connection.',
          'connect timeout · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('the answer takes too long', () async {
      expect(
        await failureFor(
          (options) => throw DioException.receiveTimeout(
            timeout: const Duration(seconds: 30),
            requestOptions: options,
          ),
        ),
        isFailure(
          'Server too slow',
          'blm.example.dev took too long to answer. Try again later.',
          'receive timeout · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('the TLS handshake fails', () async {
      expect(
        await failureFor(
          (_) => throw const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        ),
        isFailure(
          'Secure connection failed',
          secureFailed,
          'TLS · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('the certificate is rejected', () async {
      expect(
        await failureFor(
          (options) =>
              throw DioException.badCertificate(requestOptions: options),
        ),
        isFailure(
          'Secure connection failed',
          secureFailed,
          'certificate not trusted · blm.example.dev · 08:10:23',
        ),
      );
    });

    test('any other socket error names the reason of the system', () async {
      expect(
        await failureFor(
          (_) => throw socket('No route to host', 113, 'No route to host'),
        ),
        isFailure(
          notReachable,
          'Could not reach blm.example.dev. Check your internet connection.',
          'connection error (No route to host) · blm.example.dev · 08:10:23',
        ),
      );
    });
  });

  group('everything else', () {
    test('keeps the message of an ApiException, without more', () {
      expect(
        describeSignInFailure(
          const ApiException('Login failed'),
          fallback: 'Verification failed',
          now: now,
        ),
        isFailure('Login failed', null, null),
      );
    });

    test('uses the fallback with the kind of error', () {
      expect(
        describeSignInFailure(
          StateError('broken'),
          fallback: 'Login failed',
          now: now,
        ),
        isFailure(
          'Login failed',
          null,
          'unexpected error (StateError) · 08:10:23',
        ),
      );
    });

    test('never shows the password of the request', () async {
      final failure = describeSignInFailure(
        await signInFailing(
          (_) => throw socket('Connection refused', 111, 'refused'),
        ),
        fallback: 'Login failed',
        now: now,
      );
      expect(failure.report, isNot(contains('secret')));
    });

    test('names the port when the server address has one', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://192.168.12.20:8000'))
        ..httpClientAdapter = _Server(
          (_) => throw socket('Connection refused', 111, 'refused'),
        );
      late Object error;
      try {
        await dio.get<Object?>('/health');
      } on Object catch (e) {
        error = e;
      }
      expect(
        describeSignInFailure(error, fallback: 'Login failed', now: now),
        isFailure(
          notReachable,
          '192.168.12.20:8000 refused the connection. The server may be down.',
          'connection refused · 192.168.12.20:8000 · 08:10:23',
        ),
      );
    });
  });

  group('SignInFailure', () {
    test('has more to show only with an explanation or details', () {
      expect(const SignInFailure('Invalid email or password').hasMore, isFalse);
      expect(
        const SignInFailure(
          'Login failed',
          details: 'unexpected error',
        ).hasMore,
        isTrue,
      );
    });

    test('the report for copying holds every line', () {
      expect(
        const SignInFailure(
          'Server not reachable',
          explanation: 'blm.example.dev refused the connection.',
          details: 'connection refused · blm.example.dev · 08:10:23',
        ).report,
        'Server not reachable\n'
        'blm.example.dev refused the connection.\n'
        'connection refused · blm.example.dev · 08:10:23',
      );
    });
  });
}
