import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/auth/token_store.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/data/theme_store.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/auth/fakes.dart' show MemoryTokenStore;
import '../test/data/fakes.dart' show FakeGamesApi;
import 'fake_backend.dart';

const _server = 'http://fake.local';

class _NoThemeStore implements ThemeStore {
  @override
  Future<ThemeSelection?> read() async => null;

  @override
  Future<void> write(String id, List<CustomTheme> customThemes) async {}
}

/// The running app and the doubles of what is outside the backend.
class RunningApp {
  RunningApp(this.container, this.games, this.backend);

  final ProviderContainer container;
  final FakeGamesApi games;
  final FakeBackend backend;

  void go(String location) => container.read(routerProvider).go(location);
}

/// Starts the real app against [backend], as [token] is signed in or not.
Future<RunningApp> startApp(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  FakeBackend backend, {
  String? token,
}) async {
  await binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => binding.setSurfaceSize(null));
  final games = FakeGamesApi();
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      tokenStoreProvider.overrideWithValue(MemoryTokenStore(token)),
      themeStoreProvider.overrideWithValue(_NoThemeStore()),
      gamesApiProvider.overrideWithValue(games),
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
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const BacklogManagerApp(),
    ),
  );
  await container.read(authControllerProvider.notifier).restore();
  await tester.pumpAndSettle();
  return RunningApp(container, games, backend);
}

Finder fieldWithLabel(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

/// Types into a field and lets the app react, which a live window needs.
Future<void> type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> signInWithTwoFactor(WidgetTester tester) async {
  await type(tester, fieldWithLabel('Email'), 'theo@example.com');
  await type(tester, fieldWithLabel('Password'), fakePassword);
  await tester.tap(find.byKey(const Key('sign-in-submit')));
  await tester.pumpAndSettle();
  await type(tester, find.byType(TextField), fakeTwoFactorCode);
  await tester.tap(find.byKey(const Key('verify-submit')));
  await tester.pumpAndSettle();
}

List<Map<String, Object?>> library() => [
  FakeBackend.entryJson(
    id: 1,
    title: 'Hades',
    status: 'In Progress',
    genre: ['Roguelike'],
    playtime: '12.5',
    mainTime: '22',
  ),
  FakeBackend.entryJson(id: 2, title: 'Celeste', status: 'In Progress'),
  FakeBackend.entryJson(id: 3, title: 'Portal 2', status: 'Completed'),
  FakeBackend.entryJson(id: 4, title: 'Hollow Knight', status: 'Not Started'),
];

Future<RunningApp> openLibrary(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  FakeBackend backend,
) async {
  final app = await startApp(tester, binding, backend, token: fakeAccessToken);
  app.go(AppRoutes.library);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signs in with a password and a two-factor code', (tester) async {
    final backend = FakeBackend(entries: library());
    await startApp(tester, binding, backend);
    expect(find.byKey(const Key('page-sign-in')), findsOneWidget);

    await signInWithTwoFactor(tester);

    expect(find.byKey(const Key('page-home')), findsOneWidget);
    expect(backend.requests, contains('POST /api/auth/2fa/login-verify'));
    expect(backend.requests, contains('GET /api/user/me'));
  });

  testWidgets('a wrong two-factor code keeps the user on the code step', (
    tester,
  ) async {
    final backend = FakeBackend(entries: library());
    await startApp(tester, binding, backend);
    await type(tester, fieldWithLabel('Email'), 'theo@example.com');
    await type(tester, fieldWithLabel('Password'), fakePassword);
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pumpAndSettle();

    await type(tester, find.byType(TextField), '000000');
    await tester.tap(find.byKey(const Key('verify-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page-sign-in')), findsOneWidget);
    expect(find.byKey(const Key('verify-submit')), findsOneWidget);
  });

  testWidgets('the library loads and groups the games by status', (
    tester,
  ) async {
    final backend = FakeBackend(entries: library());
    await openLibrary(tester, binding, backend);

    expect(find.byKey(const Key('page-library')), findsOneWidget);
    for (final status in ['In Progress', 'Completed', 'Not Started']) {
      expect(find.byKey(Key('group-status:$status')), findsOneWidget);
    }
    for (final id in [1, 2, 3, 4]) {
      expect(find.byKey(ValueKey('tile-$id')), findsOneWidget);
    }
    expect(find.text('4 of 4 games'), findsWidgets);
  });

  testWidgets('dropping a game on another group changes its status', (
    tester,
  ) async {
    final backend = FakeBackend(entries: library());
    await openLibrary(tester, binding, backend);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tile-2'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('group-status:Completed'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(backend.entry(2)!['status'], 'Completed');
    expect(find.text('Moved "Celeste" to Completed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('editing a field in the inspector saves by itself', (
    tester,
  ) async {
    final backend = FakeBackend(entries: library());
    await openLibrary(tester, binding, backend);

    await tester.tap(find.byKey(const ValueKey('tile-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inspector')), findsOneWidget);
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    await type(tester, find.byKey(const Key('inspector-playtime')), '30');
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(backend.bodies.last['playtime'], 30);
    expect(backend.entry(1)!['playtime'], 30);
  });

  testWidgets('adds a game from the search through the creation tool', (
    tester,
  ) async {
    final backend = FakeBackend(entries: library());
    final app = await openLibrary(tester, binding, backend);
    app.games.onSearch = (term, deep) async => const [
      GameSearchResult(
        id: 7,
        title: 'Hades II',
        genres: ['Roguelike'],
        platforms: ['PC'],
        mainStory: 30,
        mainStoryWithExtras: 40,
        completionist: 60,
      ),
    ];

    await tester.tap(find.byKey(const Key('add-game-button')));
    await tester.pumpAndSettle();
    await type(tester, find.byType(TextField).last, 'Hades');
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hades II').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-creation')), findsOneWidget);

    await tester.tap(find.byKey(const Key('status-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not Started').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('creation-submit')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final created = backend.entries.where((e) => e['title'] == 'Hades II');
    expect(created, hasLength(1));
    expect(created.single['status'], 'Not Started');
    expect(created.single['platform'], ['PC']);
    expect(find.byKey(const Key('tile-5')), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('filters with the search and selects games', (tester) async {
    final backend = FakeBackend(entries: library());
    await openLibrary(tester, binding, backend);

    await type(tester, find.byKey(const Key('search-field')), 'hol');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-1')), findsNothing);
    await type(tester, find.byKey(const Key('search-field')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('select-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-2')));
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('selection-clear')));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
  });
}
