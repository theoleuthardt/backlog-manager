import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/server_url.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/auth_api.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/fakes.dart';

class HealthyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'status': 'ok'}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class Harness {
  Harness(this.tester, this.api, this.store);

  final WidgetTester tester;
  final FakeAuthApi api;
  final MemoryTokenStore store;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  String get location => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
}

Future<Harness> pumpSignIn(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeAuthApi();
  final store = MemoryTokenStore();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(api),
        tokenStoreProvider.overrideWithValue(store),
        serverUrlStoreProvider.overrideWithValue(
          ServerUrlStore(defaultUrl: 'https://api.example.com'),
        ),
        serverHealthAdapterProvider.overrideWithValue(HealthyAdapter()),
      ],
      child: const BacklogManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
  return Harness(tester, api, store);
}

Finder fieldWithLabel(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

const theo = SessionUser(
  name: 'Theo',
  email: 'theo@example.com',
  setupCompleted: true,
);

Future<void> typeCredentials(WidgetTester tester) async {
  await tester.enterText(fieldWithLabel('Email'), 'theo@example.com');
  await tester.enterText(fieldWithLabel('Password'), 'correct-horse-battery');
  await tester.pump();
}

void main() {
  group('the password step', () {
    testWidgets('has the texts and fields of the design', (tester) async {
      await pumpSignIn(tester);

      expect(find.byKey(const Key('page-sign-in')), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
      expect(
        find.text('Welcome back. Your backlog is waiting.'),
        findsOneWidget,
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Server: api.example.com'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(
        tester.widget<TextField>(fieldWithLabel('Password')).obscureText,
        isTrue,
      );
      expect(
        tester.widget<TextField>(fieldWithLabel('Email')).obscureText,
        isFalse,
      );
    });

    testWidgets('keeps the button off until both fields are filled', (
      tester,
    ) async {
      await pumpSignIn(tester);
      final button = find.byKey(const Key('sign-in-submit'));

      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: button, matching: find.byType(Opacity)).first,
            )
            .opacity,
        0.4,
      );

      await typeCredentials(tester);

      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: button, matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
      );
    });

    testWidgets('signs in with the typed credentials and goes home', (
      tester,
    ) async {
      final app = await pumpSignIn(tester);
      String? sentEmail;
      String? sentPassword;
      app.api.onLogin = (email, password) async {
        sentEmail = email;
        sentPassword = password;
        return const LoginSucceeded('jwt');
      };
      app.api.onCurrentUser = () async => theo;

      await typeCredentials(tester);
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pumpAndSettle();

      expect(sentEmail, 'theo@example.com');
      expect(sentPassword, 'correct-horse-battery');
      expect(app.location, AppRoutes.home);
      expect(find.byKey(const Key('sidebar')), findsOneWidget);
      expect(app.store.token, 'jwt');
    });

    testWidgets('submits with Enter in the password field', (tester) async {
      final app = await pumpSignIn(tester);
      app.api.onLogin = (email, password) async => const LoginSucceeded('jwt');
      app.api.onCurrentUser = () async => theo;

      await typeCredentials(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(app.api.calls, contains('login theo@example.com'));
    });

    testWidgets('shows a spinner and "Logging in..." while the request runs', (
      tester,
    ) async {
      final app = await pumpSignIn(tester);
      final pending = Completer<LoginOutcome>();
      app.api.onLogin = (email, password) => pending.future;

      await typeCredentials(tester);
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pump();

      expect(find.text('Logging in...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(const LoginNeedsTwoFactor('c'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows the error of the backend in a banner above the form', (
      tester,
    ) async {
      final app = await pumpSignIn(tester);
      app.api.onLogin = (email, password) async => throw const ApiException(
        'Invalid email or password',
        statusCode: 401,
      );

      await typeCredentials(tester);
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byKey(const Key('error-banner'))).dy,
        lessThan(tester.getTopLeft(find.text('Email')).dy),
      );
      final tokens = Theme.of(
        tester.element(find.byKey(const Key('error-banner'))),
      ).extension<ShelfTokens>()!;
      final text = tester.widget<Text>(find.text('Invalid email or password'));
      expect(text.style!.color, tokens.danger);
      expect(find.text('Logging in...'), findsNothing);
    });
  });

  group('the two-factor step', () {
    Future<Harness> reachTwoFactor(WidgetTester tester) async {
      final app = await pumpSignIn(tester);
      app.api.onLogin = (email, password) async =>
          const LoginNeedsTwoFactor('challenge-1');
      await typeCredentials(tester);
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('asks for the code with the texts of the design', (
      tester,
    ) async {
      await reachTwoFactor(tester);

      expect(find.text('Two-factor authentication'), findsOneWidget);
      expect(find.text('Verify it is you'), findsOneWidget);
      expect(
        find.text(
          'Enter the 6-digit code from your authenticator app, or one of your backup codes.',
        ),
        findsOneWidget,
      );
      expect(find.text('Verification code'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Start over'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
    });

    testWidgets('verifies a code, whitespace removed, and goes home', (
      tester,
    ) async {
      final app = await reachTwoFactor(tester);
      String? sent;
      app.api.onVerify = (challenge, code) async {
        sent = code;
        return 'jwt';
      };
      app.api.onCurrentUser = () async => theo;

      await tester.enterText(find.byType(TextField), '123 456');
      await tester.pump();
      await tester.tap(find.byKey(const Key('verify-submit')));
      await tester.pumpAndSettle();

      expect(sent, '123456');
      expect(app.location, AppRoutes.home);
    });

    testWidgets('shows a wrong code as a banner and stays on the step', (
      tester,
    ) async {
      final app = await reachTwoFactor(tester);
      app.api.onVerify = (challenge, code) async => throw const ApiException(
        'Invalid verification code',
        statusCode: 401,
      );

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('verify-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid verification code'), findsOneWidget);
      expect(find.text('Two-factor authentication'), findsOneWidget);
    });

    testWidgets('goes back to the password form with "Start over"', (
      tester,
    ) async {
      await reachTwoFactor(tester);

      await tester.tap(find.text('Start over'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Two-factor authentication'), findsNothing);
    });
  });

  group('changing the server', () {
    testWidgets(
      'opens a sheet, rejects an insecure address and keeps the server',
      (tester) async {
        await pumpSignIn(tester);

        await tester.tap(find.text('Change'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('server-url-field')),
          'http://api.example.org',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('server-save')));
        await tester.pumpAndSettle();

        expect(find.textContaining('must use https'), findsOneWidget);
        expect(find.text('Server: api.example.com'), findsOneWidget);
      },
    );

    testWidgets('saves a valid, reachable server and shows it', (tester) async {
      final app = await pumpSignIn(tester);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('server-url-field')),
        'https://backlog.example.org',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('server-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('server-url-field')), findsNothing);
      expect(find.text('Server: backlog.example.org'), findsOneWidget);
      expect(
        await app.container.read(serverUrlStoreProvider).read(),
        'https://backlog.example.org',
      );
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    for (final step in ['password', 'two-factor']) {
      testWidgets('golden: the $step step in $themeId', (tester) async {
        final app = await pumpSignIn(tester);
        app.container.read(themeIdProvider.notifier).select(themeId);
        app.api.onLogin = (email, password) async => step == 'password'
            ? throw const ApiException(
                'Invalid email or password',
                statusCode: 401,
              )
            : const LoginNeedsTwoFactor('challenge-1');
        await typeCredentials(tester);
        await tester.tap(find.byKey(const Key('sign-in-submit')));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/sign_in_${step}_$themeId.png'),
        );
      });
    }
  }
}
