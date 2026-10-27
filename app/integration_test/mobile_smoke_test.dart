import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/design/atmosphere.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/data/fakes.dart' show FakeGamesApi;
import 'fake_backend.dart';

const _server = 'http://fake.local';

/// The smoke test of a mobile build on a device or emulator: the real app
/// with the real token and theme stores (the platform's keystore and
/// preferences), so a plugin without an Android or iOS implementation fails
/// here. Only the backend is the in-memory one of the desktop flows. The
/// layout is not checked: overflow errors are dropped until the responsive
/// shell (#521) and its golden tests at phone and handheld sizes take over;
/// every other error still fails the test.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  atmosphereMotion = false;
  coverImageDelay = Duration.zero;

  testWidgets('starts, signs in and keeps the token in the keystore', (
    tester,
  ) async {
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      reportError?.call(details);
    };
    addTearDown(() => FlutterError.onError = reportError);
    final backend = FakeBackend(entries: []);
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        gamesApiProvider.overrideWithValue(FakeGamesApi()),
        serverUrlProvider.overrideWith((ref) async => _server),
        apiDioProvider.overrideWith(
          (ref) async => createApiDio(
            baseUrl: _server,
            readToken: ref.read(tokenStoreProvider).read,
            onUnauthorized: () =>
                ref.read(authControllerProvider.notifier).sessionExpired(),
            adapter: backend,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(tokenStoreProvider).clear();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BacklogManagerApp(),
      ),
    );
    await container.read(authControllerProvider.notifier).restore();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-sign-in')), findsOneWidget);

    final auth = container.read(authControllerProvider.notifier);
    await auth.login('theo@example.com', fakePassword);
    await auth.verify(fakeTwoFactorCode);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-home')), findsOneWidget);

    expect(await container.read(tokenStoreProvider).read(), fakeAccessToken);
    expect(backend.requests, contains('GET /api/user/me'));
    await container.read(tokenStoreProvider).clear();
  });
}
