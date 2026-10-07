import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';

class SignedIn extends SessionNotifier {
  @override
  SessionState build() => const SessionSignedIn(
    SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: true),
  );
}

BacklogEntry game(
  int id,
  String title, {
  String status = 'Not Started',
  double? mainTime,
  double? playtime,
  int? reviewStars,
  DateTime? completedAt,
  int? steamAppId,
}) {
  return BacklogEntry(
    id: id,
    title: title,
    status: status,
    mainTime: mainTime,
    playtime: playtime,
    reviewStars: reviewStars,
    completedAt: completedAt,
    steamAppId: steamAppId,
  );
}

final backlog = [
  game(
    1,
    'Elden Ring',
    status: 'In Progress',
    mainTime: 60,
    playtime: 41,
    steamAppId: 1245620,
  ),
  game(2, 'Celeste', mainTime: 8),
  game(3, 'Portal 2', mainTime: 9),
  game(4, 'Disco Elysium', mainTime: 24),
  game(
    5,
    'Hades II',
    status: 'Completed',
    mainTime: 22,
    reviewStars: 9,
    completedAt: DateTime(DateTime.now().year, 1, 15),
  ),
  game(
    6,
    'Tunic',
    status: 'Completed',
    mainTime: 12,
    reviewStars: 8,
    completedAt: DateTime(2024, 5, 1),
  ),
];

Future<ProviderContainer> pumpHome(
  WidgetTester tester,
  FakeBacklogApi api, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        sessionProvider.overrideWith(SignedIn.new),
        backlogApiProvider.overrideWithValue(api),
      ],
      child: const BacklogManagerApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Finder inHome(Finder matching) =>
    find.descendant(of: find.byKey(const Key('page-home')), matching: matching);

void main() {
  group('the states', () {
    testWidgets('shows "Loading your backlog..." while the entries load', (
      tester,
    ) async {
      final pending = Completer<List<BacklogEntry>>();
      final api = FakeBacklogApi()..onEntries = (_) => pending.future;

      await pumpHome(tester, api, settle: false);

      expect(find.text('Loading your backlog...'), findsOneWidget);
      pending.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('shows the error message and tries again on request', (
      tester,
    ) async {
      var failing = true;
      final api = FakeBacklogApi(entries: backlog)
        ..onEntries = (_) async {
          if (failing) throw const ApiException('Server unavailable');
          return backlog;
        };
      await pumpHome(tester, api);
      expect(find.text('Server unavailable'), findsOneWidget);

      failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Server unavailable'), findsNothing);
      expect(find.text('Continue playing'.toUpperCase()), findsOneWidget);
    });

    testWidgets('shows an empty state with the ways to fill the backlog', (
      tester,
    ) async {
      await pumpHome(tester, FakeBacklogApi());

      expect(find.text('Your backlog is empty'), findsOneWidget);
      expect(find.text('Add a game'), findsOneWidget);
      expect(find.text('Sync Steam'), findsOneWidget);
    });
  });

  group('with a backlog', () {
    testWidgets('shows the four stat tiles', (tester) async {
      await pumpHome(tester, FakeBacklogApi(entries: backlog));

      expect(inHome(find.text('In backlog')), findsOneWidget);
      expect(inHome(find.text('6')), findsOneWidget);
      expect(inHome(find.text('Time to beat')), findsOneWidget);
      expect(inHome(find.text('135')), findsOneWidget);
      expect(inHome(find.text('Playing now')), findsOneWidget);
      expect(inHome(find.text('Completed this year')), findsOneWidget);
    });

    testWidgets(
      'shows the game to continue with its hours and the achievements to go',
      (tester) async {
        final api = FakeBacklogApi(entries: backlog);
        await pumpHome(tester, api);

        expect(find.text('CONTINUE PLAYING'), findsOneWidget);
        expect(inHome(find.text('Elden Ring')), findsWidgets);
        expect(find.text('41 of 60 h · 12 achievements to go'), findsOneWidget);
        expect(api.calls, contains('achievements 1245620'));
      },
    );

    testWidgets('asks for the achievements again in the next session', (
      tester,
    ) async {
      final api = FakeBacklogApi(entries: backlog);
      final container = await pumpHome(tester, api);

      container.read(sessionGenerationProvider.notifier).bump();
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c == 'achievements 1245620').length, 2);
    });

    testWidgets('leaves out the achievements for a game without Steam', (
      tester,
    ) async {
      final entries = [
        game(1, 'Hades', status: 'In Progress', mainTime: 22, playtime: 5),
        game(2, 'Celeste', mainTime: 8),
      ];
      await pumpHome(tester, FakeBacklogApi(entries: entries));

      expect(find.text('5 of 22 h'), findsOneWidget);
    });

    testWidgets('marks the game as completed and tells about a failure', (
      tester,
    ) async {
      final api = FakeBacklogApi(entries: backlog)
        ..onUpdate = (id, update) async =>
            throw const ApiException('Not allowed');
      await pumpHome(tester, api);

      await tester.tap(find.text('Mark as completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(api.calls, contains('update 1 {status: Completed}'));
      expect(find.text('Not allowed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('opens the details of the game in the library', (tester) async {
      final container = await pumpHome(
        tester,
        FakeBacklogApi(entries: backlog),
      );

      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      final uri = container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri;
      expect(uri.path, '/library');
      expect(uri.queryParameters, {'entry': '1'});
    });

    testWidgets(
      'lists the games to start, the shortest first, with their hours',
      (tester) async {
        await pumpHome(tester, FakeBacklogApi(entries: backlog));

        final up = find.byKey(const Key('shelf-up-next'));
        expect(find.text('Up next'), findsOneWidget);
        expect(find.text('Short games first'), findsOneWidget);
        final celeste = tester
            .getTopLeft(find.descendant(of: up, matching: find.text('Celeste')))
            .dx;
        final portal = tester
            .getTopLeft(
              find.descendant(of: up, matching: find.text('Portal 2')),
            )
            .dx;
        final disco = tester
            .getTopLeft(
              find.descendant(of: up, matching: find.text('Disco Elysium')),
            )
            .dx;
        expect(celeste, lessThan(portal));
        expect(portal, lessThan(disco));
        expect(find.text('8 h to beat'), findsOneWidget);
      },
    );

    testWidgets('opens the library filtered to the status with "See all"', (
      tester,
    ) async {
      final container = await pumpHome(
        tester,
        FakeBacklogApi(entries: backlog),
      );

      await tester.tap(find.byKey(const Key('see-all-up-next')));
      await tester.pumpAndSettle();

      final uri = container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri;
      expect(uri.path, '/library');
      expect(uri.queryParameters, {'status': 'Not Started'});
    });

    testWidgets(
      'lists the completed games with their rating, the latest first',
      (tester) async {
        await pumpHome(tester, FakeBacklogApi(entries: backlog));

        final done = find.byKey(const Key('shelf-recently-completed'));
        expect(find.text('Recently completed'), findsOneWidget);
        expect(
          tester
              .getTopLeft(
                find.descendant(of: done, matching: find.text('Hades II')),
              )
              .dx,
          lessThan(
            tester
                .getTopLeft(
                  find.descendant(of: done, matching: find.text('Tunic')),
                )
                .dx,
          ),
        );
        expect(find.text('9/10'), findsOneWidget);
      },
    );

    testWidgets('shows the number of games in the status bar', (tester) async {
      final container = await pumpHome(
        tester,
        FakeBacklogApi(entries: backlog),
      );

      expect(container.read(shellStatusProvider).counts, '6 games');
      expect(
        find.descendant(
          of: find.byKey(const Key('status-bar')),
          matching: find.text('6 games'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps the shelves out when there is nothing for them', (
      tester,
    ) async {
      final entries = [game(1, 'Hades', status: 'In Progress', playtime: 3)];
      await pumpHome(tester, FakeBacklogApi(entries: entries));

      expect(find.text('Up next'), findsNothing);
      expect(find.text('Recently completed'), findsNothing);
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the home screen in $themeId', (tester) async {
      final container = await pumpHome(
        tester,
        FakeBacklogApi(entries: backlog),
      );
      container.read(themeIdProvider.notifier).select(themeId);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_$themeId.png'),
      );
    });
  }
}
