import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';

class SignedIn extends SessionNotifier {
  SignedIn(this.defaultSort);

  final String defaultSort;

  @override
  SessionState build() => SessionSignedIn(
    SessionUser(
      name: 'Theo',
      email: 'theo@example.com',
      setupCompleted: true,
      defaultSort: defaultSort,
    ),
  );
}

BacklogEntry game(
  int id,
  String title, {
  String status = 'Not Started',
  double? mainTime,
  double? playtime,
  List<String> genre = const [],
  bool inSharedSpace = false,
}) => BacklogEntry(
  id: id,
  title: title,
  status: status,
  mainTime: mainTime,
  playtime: playtime,
  genre: genre,
  inSharedSpace: inSharedSpace,
);

final backlog = [
  game(
    1,
    'Elden Ring',
    status: 'In Progress',
    mainTime: 60,
    playtime: 41,
    genre: ['RPG'],
  ),
  game(2, 'Celeste', mainTime: 8, genre: ['Platformer']),
  game(3, 'Portal 2', mainTime: 9, genre: ['Puzzle']),
  game(
    4,
    'Disco Elysium',
    status: 'On Hold',
    mainTime: 24,
    playtime: 120,
    genre: ['RPG'],
  ),
  game(5, 'Hades II', status: 'Completed', mainTime: 22, playtime: 30),
  game(
    6,
    'Tunic',
    status: 'Completed',
    mainTime: 12,
    playtime: 14,
    inSharedSpace: true,
  ),
];

Future<ProviderContainer> pumpLibrary(
  WidgetTester tester,
  FakeBacklogApi api, {
  String defaultSort = 'status',
  bool settle = true,
  double height = 2400,
}) async {
  tester.view.physicalSize = Size(1440, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        sessionProvider.overrideWith(() => SignedIn(defaultSort)),
        backlogApiProvider.overrideWithValue(api),
      ],
      child: const BacklogManagerApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(routerProvider).go(AppRoutes.library);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return container;
}

Finder inLibrary(Finder matching) => find.descendant(
  of: find.byKey(const Key('page-library')),
  matching: matching,
);

Future<void> chooseSort(
  WidgetTester tester,
  String current,
  String next,
) async {
  await tester.tap(find.text('Sort: $current'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(next).last);
  await tester.pumpAndSettle();
}

double top(WidgetTester tester, String text) =>
    tester.getTopLeft(inLibrary(find.text(text))).dy;

void main() {
  group('the states', () {
    testWidgets('shows "Loading your backlog..." while the entries load', (
      tester,
    ) async {
      final pending = Completer<List<BacklogEntry>>();
      final api = FakeBacklogApi()..onEntries = (_) => pending.future;

      await pumpLibrary(tester, api, settle: false);

      expect(find.text('Loading your backlog...'), findsOneWidget);
      pending.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('shows the error message and loads again on request', (
      tester,
    ) async {
      var failing = true;
      final api = FakeBacklogApi(entries: backlog)
        ..onEntries = (_) async {
          if (failing) throw const ApiException('Server unavailable');
          return backlog;
        };
      await pumpLibrary(tester, api);
      expect(find.text('Server unavailable'), findsOneWidget);

      failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Server unavailable'), findsNothing);
      expect(find.text('Library'), findsWidgets);
    });

    testWidgets('invites to add a first game when the backlog is empty', (
      tester,
    ) async {
      final container = await pumpLibrary(tester, FakeBacklogApi());

      expect(find.text('Your backlog is empty'), findsOneWidget);
      expect(find.text('Start by adding your first game!'), findsOneWidget);
      await tester.tap(find.text('Add a game'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        AppRoutes.creationTool,
      );
    });
  });

  group('the toolbar', () {
    testWidgets('shows the count and the hours to beat of the whole backlog', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

      expect(inLibrary(find.text('6 of 6 games')), findsOneWidget);
      expect(inLibrary(find.text('135 h to beat')), findsOneWidget);
    });

    testWidgets('opens the creation tool from "Add game"', (tester) async {
      final container = await pumpLibrary(
        tester,
        FakeBacklogApi(entries: backlog),
      );

      await tester.tap(inLibrary(find.text('Add game')));
      await tester.pumpAndSettle();

      expect(
        container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        AppRoutes.creationTool,
      );
    });

    testWidgets('names the sort option on its button', (tester) async {
      await pumpLibrary(
        tester,
        FakeBacklogApi(entries: backlog),
        defaultSort: 'playtime',
      );

      expect(find.text('Sort: Playtime'), findsOneWidget);
    });
  });

  group('grouped by status', () {
    testWidgets('has one group per status with its count, the empty ones too', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

      for (final status in ['Not Started', 'In Progress', 'On Hold']) {
        expect(find.byKey(Key('group-status:$status')), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('group-status:Not Started')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('group-status:Dropped')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('group-status:Dropped')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('puts a custom status after the built-in ones', (tester) async {
      final api = FakeBacklogApi(
        entries: [
          ...backlog,
          game(7, 'Hollow Knight', status: 'Wishlist'),
        ],
      )..statusList = const [CustomStatus(id: 1, name: 'Wishlist')];
      await pumpLibrary(tester, api);

      expect(find.byKey(const Key('group-status:Wishlist')), findsOneWidget);
    });

    testWidgets('lists the games of a group as covers', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

      expect(inLibrary(find.text('Celeste')), findsWidgets);
      expect(inLibrary(find.text('Portal 2')), findsWidgets);
    });

    testWidgets('shows the playtime against the main story below a cover', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

      expect(find.text('41 / 60 h'), findsOneWidget);
    });

    testWidgets('marks a game that is also in the shared space', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

      expect(find.byTooltip('Also in your shared space'), findsOneWidget);
    });
  });

  group('sorting', () {
    testWidgets('groups by the chosen option with its headlines', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

      await chooseSort(tester, 'Status', 'Playtime');

      expect(find.text('Sort: Playtime'), findsOneWidget);
      expect(
        find.byKey(const Key('group-playtime:100h or more')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('group-playtime:Not played')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('group-playtime:10-50h')), findsOneWidget);
    });

    testWidgets('starts the playtime sort with the longest played first', (
      tester,
    ) async {
      await pumpLibrary(
        tester,
        FakeBacklogApi(entries: backlog),
        defaultSort: 'playtime',
      );

      expect(
        tester
            .getTopLeft(find.byKey(const Key('group-playtime:100h or more')))
            .dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('group-playtime:10-50h'))).dy,
        ),
      );
    });

    testWidgets('reverses the groups with the direction toggle', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));
      final before = tester
          .getTopLeft(find.byKey(const Key('group-status:Not Started')))
          .dy;

      await tester.tap(find.byTooltip('Sort direction'));
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(
        find.byKey(const Key('group-status:Not Started')),
      );
      expect(after.dy, isNot(before));
    });
  });

  group('groups', () {
    testWidgets('fold away and come back', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));
      expect(inLibrary(find.text('Celeste')), findsWidgets);

      await tester.tap(
        find.byKey(const Key('group-toggle-status:Not Started')),
      );
      await tester.pumpAndSettle();
      expect(inLibrary(find.text('Celeste')), findsNothing);

      await tester.tap(
        find.byKey(const Key('group-toggle-status:Not Started')),
      );
      await tester.pumpAndSettle();
      expect(inLibrary(find.text('Celeste')), findsWidgets);
    });

    testWidgets('page their covers 60 at a time', (tester) async {
      final many = [for (var i = 1; i <= 130; i++) game(i, 'Game $i')];
      await pumpLibrary(tester, FakeBacklogApi(entries: many));

      Future<void> reveal(String label) async {
        await tester.scrollUntilVisible(
          find.text(label),
          400,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await reveal('Show 60 more (70 hidden)');
      await reveal('Show 10 more (10 hidden)');

      expect(find.textContaining('more ('), findsNothing);
    });

    testWidgets('only build the covers that are on screen', (tester) async {
      final many = [
        for (var i = 1; i <= 2000; i++) game(i, 'Game $i', status: 'Completed'),
      ];
      await pumpLibrary(tester, FakeBacklogApi(entries: many), height: 900);

      expect(find.byType(ShelfCover).evaluate().length, lessThan(100));
    });
  });

  group('the list layout', () {
    testWidgets('shows one row per game with its status and playtime', (
      tester,
    ) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));

      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('library-row-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('library-row-1')),
          matching: find.text('Elden Ring'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('library-row-1')),
          matching: find.text('41 / 60 h'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ShelfCover), findsNothing);
    });

    testWidgets('goes back to the covers', (tester) async {
      await pumpLibrary(tester, FakeBacklogApi(entries: backlog));
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('library-row-1')), findsNothing);
      expect(find.byType(ShelfCover), findsWidgets);
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the library in $themeId', (tester) async {
      final container = await pumpLibrary(
        tester,
        FakeBacklogApi(entries: backlog),
        height: 900,
      );
      container.read(themeIdProvider.notifier).select(themeId);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/library_$themeId.png'),
      );
    });
  }
}
