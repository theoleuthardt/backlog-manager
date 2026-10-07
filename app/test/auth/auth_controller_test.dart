import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/auth_api.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const theo = SessionUser(
  name: 'Theo',
  email: 'theo@example.com',
  setupCompleted: true,
);

ProviderContainer containerWith(FakeAuthApi api, MemoryTokenStore store) {
  final container = ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(api),
      tokenStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AuthController controllerOf(ProviderContainer container) =>
    container.read(authControllerProvider.notifier);

void main() {
  late FakeAuthApi api;
  late MemoryTokenStore store;
  late ProviderContainer container;

  setUp(() {
    api = FakeAuthApi();
    store = MemoryTokenStore();
    container = containerWith(api, store);
  });

  SessionState session() => container.read(sessionProvider);
  LoginFlow flow() => container.read(authControllerProvider);

  group('restoring the session at start', () {
    test('is signed out without a stored token and asks nothing', () async {
      await controllerOf(container).restore();

      expect(session(), isA<SessionSignedOut>());
      expect(api.calls, isEmpty);
    });

    test('shows the checking state while the token is validated', () async {
      store.token = 'jwt';
      final pending = Completer<SessionUser>();
      api.onCurrentUser = () => pending.future;
      final seen = <SessionState>[];
      container.listen(sessionProvider, (_, next) => seen.add(next));

      final restoring = controllerOf(container).restore();
      await Future<void>.delayed(Duration.zero);
      expect(session(), isA<SessionLoading>());

      pending.complete(theo);
      await restoring;
      expect(seen.map((s) => s.runtimeType), [SessionLoading, SessionSignedIn]);
    });

    test('signs in with a valid stored token', () async {
      store.token = 'jwt';
      api.onCurrentUser = () async => theo;

      await controllerOf(container).restore();

      expect((session() as SessionSignedIn).user.name, 'Theo');
      expect(store.token, 'jwt');
    });

    test('drops a revoked token and returns to sign-in', () async {
      store.token = 'revoked';
      api.onCurrentUser = () async =>
          throw const ApiException('Not authenticated', statusCode: 401);

      await controllerOf(container).restore();

      expect(session(), isA<SessionSignedOut>());
      expect(store.token, isNull);
    });

    test('keeps the token when the server cannot be reached', () async {
      store.token = 'jwt';
      api.onCurrentUser = () async =>
          throw const ApiException('Could not reach the server');

      await controllerOf(container).restore();

      expect(session(), isA<SessionSignedOut>());
      expect(store.token, 'jwt');
      expect(flow().error, 'Could not reach the server');
    });
  });

  group('signing in with a password', () {
    test('stores the token and signs in', () async {
      api.onLogin = (email, password) async => const LoginSucceeded('jwt');
      api.onCurrentUser = () async => theo;

      await controllerOf(container)
          .login('theo@example.com', 'secret-password');

      expect(store.token, 'jwt');
      expect(session(), isA<SessionSignedIn>());
      expect(flow().busy, isFalse);
      expect(flow().error, isNull);
    });

    test('is busy while the request runs', () async {
      final pending = Completer<LoginOutcome>();
      api.onLogin = (email, password) => pending.future;
      api.onCurrentUser = () async => theo;

      final login = controllerOf(container).login('a@b.de', 'x');
      await Future<void>.delayed(Duration.zero);
      expect(flow().busy, isTrue);

      pending.complete(const LoginSucceeded('jwt'));
      await login;
      expect(flow().busy, isFalse);
    });

    test('shows the message of the backend for wrong credentials', () async {
      api.onLogin = (email, password) async => throw const ApiException(
        'Invalid email or password',
        statusCode: 401,
      );

      await controllerOf(container).login('a@b.de', 'wrong');

      expect(flow().error, 'Invalid email or password');
      expect(flow().busy, isFalse);
      expect(session(), isA<SessionSignedOut>());
      expect(store.token, isNull);
    });

    test('clears an old error when the next attempt starts', () async {
      api.onLogin = (email, password) async =>
          throw const ApiException('Account locked');
      await controllerOf(container).login('a@b.de', 'x');
      expect(flow().error, 'Account locked');

      final pending = Completer<LoginOutcome>();
      api.onLogin = (email, password) => pending.future;
      final second = controllerOf(container).login('a@b.de', 'x');
      await Future<void>.delayed(Duration.zero);
      expect(flow().error, isNull);

      pending.complete(const LoginSucceeded('jwt'));
      api.onCurrentUser = () async => theo;
      await second;
    });

    test(
      'moves to the two-factor step when the account has two-factor',
      () async {
        api.onLogin = (email, password) async =>
            const LoginNeedsTwoFactor('challenge-1');

        await controllerOf(container).login('a@b.de', 'x');

        expect(flow().step, LoginStep.twoFactor);
        expect(flow().challengeToken, 'challenge-1');
        expect(store.token, isNull);
        expect(session(), isA<SessionSignedOut>());
      },
    );
  });

  group('two-factor', () {
    setUp(() async {
      api.onLogin = (email, password) async =>
          const LoginNeedsTwoFactor('challenge-1');
      await controllerOf(container).login('a@b.de', 'x');
    });

    test('signs in with a six digit code after stripping whitespace', () async {
      String? sent;
      api.onVerify = (challenge, code) async {
        sent = code;
        expect(challenge, 'challenge-1');
        return 'jwt';
      };
      api.onCurrentUser = () async => theo;

      await controllerOf(container).verify(' 123 456 ');

      expect(sent, '123456');
      expect(store.token, 'jwt');
      expect(session(), isA<SessionSignedIn>());
    });

    test('accepts a backup code', () async {
      String? sent;
      api.onVerify = (challenge, code) async {
        sent = code;
        return 'jwt';
      };
      api.onCurrentUser = () async => theo;

      await controllerOf(container).verify('abcd-efgh');

      expect(sent, 'abcd-efgh');
      expect(session(), isA<SessionSignedIn>());
    });

    test('shows the error of a wrong code and stays on the step', () async {
      api.onVerify = (challenge, code) async => throw const ApiException(
        'Invalid verification code',
        statusCode: 401,
      );

      await controllerOf(container).verify('000000');

      expect(flow().error, 'Invalid verification code');
      expect(flow().step, LoginStep.twoFactor);
      expect(flow().busy, isFalse);
    });

    test('discards a code answer that arrives after starting over', () async {
      final pending = Completer<String>();
      api.onVerify = (challenge, code) => pending.future;
      api.onCurrentUser = () async => theo;

      final verify = controllerOf(container).verify('123456');
      await Future<void>.delayed(Duration.zero);
      controllerOf(container).startOver();
      pending.complete('jwt');
      await verify;

      expect(session(), isNot(isA<SessionSignedIn>()));
      expect(store.token, isNull);
      expect(flow().step, LoginStep.password);
    });

    test('starts over with the password form', () {
      controllerOf(container).startOver();

      expect(flow().step, LoginStep.password);
      expect(flow().challengeToken, isNull);
      expect(flow().error, isNull);
    });
  });

  group('signing out', () {
    test(
      'clears the token and the session and starts a new data generation',
      () async {
        api.onLogin = (email, password) async => const LoginSucceeded('jwt');
        api.onCurrentUser = () async => theo;
        await controllerOf(container).login('a@b.de', 'x');
        final before = container.read(sessionGenerationProvider);

        await controllerOf(container).signOut();

        expect(session(), isA<SessionSignedOut>());
        expect(store.token, isNull);
        expect(container.read(sessionGenerationProvider), greaterThan(before));
        expect(flow().step, LoginStep.password);
      },
    );

    test('ignores a sign-in that finishes after the user signed out', () async {
      final pending = Completer<LoginOutcome>();
      api.onLogin = (email, password) => pending.future;
      api.onCurrentUser = () async => theo;

      final login = controllerOf(container).login('a@b.de', 'x');
      await Future<void>.delayed(Duration.zero);
      await controllerOf(container).signOut();
      pending.complete(const LoginSucceeded('late-jwt'));
      await login;

      expect(session(), isA<SessionSignedOut>());
      expect(store.token, isNull);
    });

    test('ignores a session check that finishes after a sign-out', () async {
      store.token = 'jwt';
      final pending = Completer<SessionUser>();
      api.onCurrentUser = () => pending.future;

      final restoring = controllerOf(container).restore();
      await Future<void>.delayed(Duration.zero);
      await controllerOf(container).signOut();
      pending.complete(theo);
      await restoring;

      expect(session(), isA<SessionSignedOut>());
    });
  });

  group('an expired session', () {
    test(
      'signs a signed-in user out with a notice and clears the token',
      () async {
        api.onLogin = (email, password) async => const LoginSucceeded('jwt');
        api.onCurrentUser = () async => theo;
        await controllerOf(container).login('a@b.de', 'x');

        await controllerOf(container).sessionExpired();

        expect(session(), isA<SessionSignedOut>());
        expect(store.token, isNull);
        expect(flow().error, 'Your session has ended. Sign in again.');
      },
    );

    test('does not replace the error of a failed sign-in', () async {
      api.onLogin = (email, password) async => throw const ApiException(
        'Invalid email or password',
        statusCode: 401,
      );
      await controllerOf(container).login('a@b.de', 'wrong');

      await controllerOf(container).sessionExpired();

      expect(flow().error, 'Invalid email or password');
    });
  });

  group('refreshing the user', () {
    test('reads the user again and keeps the session', () async {
      api.onLogin = (email, password) async => const LoginSucceeded('jwt');
      api.onCurrentUser = () async => theo;
      await controllerOf(container).login('a@b.de', 'x');

      api.onCurrentUser = () async => const SessionUser(
        name: 'Theo',
        email: 'new@example.com',
        setupCompleted: true,
      );
      await controllerOf(container).refreshUser();

      expect((session() as SessionSignedIn).user.email, 'new@example.com');
    });
  });
}
