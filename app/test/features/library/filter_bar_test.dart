import 'package:backlog_manager/app.dart';
import 'package:backlog_manager/data/backlog_api.dart';
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
  @override
  SessionState build() => const SessionSignedIn(
    SessionUser(name: 'Theo', email: 'theo@example.com', setupCompleted: true),
  );
}

BacklogEntry game(
  int id,
  String title, {
  String status = 'Not Started',
  double? playtime,
  double? mainTime,
  List<String> genre = const [],
  List<String> platform = const [],
  bool owned = false,
}) {
  return BacklogEntry(
    id: id,
    title: title,
    status: status,
    playtime: playtime,
    mainTime: mainTime,
    genre: genre,
    platform: platform,
    owned: owned,
  );
}

FakeBacklogApi backlog({bool withCategories = true}) {
  final api = FakeBacklogApi(
    entries: [
      game(
        1,
        'Elden Ring',
        status: 'In Progress',
        playtime: 41,
        mainTime: 60,
        genre: ['RPG'],
        platform: ['PC'],
        owned: true,
      ),
      game(
        2,
        'Celeste',
        mainTime: 8,
        genre: ['Platformer'],
        platform: ['Switch'],
      ),
      game(
        3,
        'Portal 2',
        mainTime: 9,
        genre: ['Puzzle'],
        platform: ['PC', 'Switch'],
        owned: true,
      ),
      game(
        4,
        'Disco Elysium',
        status: 'On Hold',
        playtime: 120,
        mainTime: 24,
        genre: ['RPG'],
        platform: ['PC'],
      ),
    ],
  );
  if (withCategories) {
    api
      ..categoryList = const [
        Category(id: 1, name: 'Co-op nights', color: '#38bdf8'),
      ]
      ..entriesByCategory = {
        1: [game(3, 'Portal 2')],
      };
  }
  return api;
}

Future<ProviderContainer> pumpLibrary(
  WidgetTester tester,
  FakeBacklogApi api,
) async {
  tester.view.physicalSize = const Size(1440, 2400);
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
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(routerProvider).go(AppRoutes.library);
  await tester.pumpAndSettle();
  return container;
}

Finder inLibrary(Finder matching) => find.descendant(
  of: find.byKey(const Key('page-library')),
  matching: matching,
);

Finder cover(String title) =>
    find.descendant(of: find.byType(ShelfCover), matching: find.text(title));

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> addFilter(WidgetTester tester, String field) async {
  await tapKey(tester, 'add-filter');
  await tapKey(tester, 'add-filter-field-$field');
}

Future<void> pick(WidgetTester tester, String value) async {
  await tapKey(tester, 'filter-option-$value');
}

Future<void> closePopover(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 700));
  await tester.pumpAndSettle();
}

void main() {
  group('the bar', () {
    testWidgets('starts without tokens, with the add button and the switch', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());

      expect(find.byKey(const Key('filter-bar')), findsOneWidget);
      expect(find.text('+ Add filter'), findsOneWidget);
      expect(find.byKey(const Key('owned-only')), findsOneWidget);
      expect(find.byKey(const Key('filter-reset')), findsNothing);
      expect(find.textContaining('Genre'), findsNothing);
    });

    testWidgets('keeps the sort and view controls of the library', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());

      expect(find.text('Sort: Status'), findsOneWidget);
      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
    });
  });

  group('adding a filter', () {
    testWidgets('lists the fields and offers categories only when they exist', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await tapKey(tester, 'add-filter');

      for (final name in [
        'platform',
        'genre',
        'status',
        'category',
        'interest',
        'reviewStars',
        'playtime',
        'mainTime',
        'mainPlusExtraTime',
        'completionTime',
      ]) {
        expect(find.byKey(Key('add-filter-field-$name')), findsOneWidget);
      }
    });

    testWidgets('leaves out the category field without categories', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog(withCategories: false));
      await tapKey(tester, 'add-filter');

      expect(find.byKey(const Key('add-filter-field-category')), findsNothing);
      expect(find.byKey(const Key('add-filter-field-genre')), findsOneWidget);
    });

    testWidgets('searches the fields', (tester) async {
      await pumpLibrary(tester, backlog());
      await tapKey(tester, 'add-filter');

      await tester.enterText(
        find.byKey(const Key('add-filter-search')),
        'TIME',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('add-filter-field-playtime')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('add-filter-field-genre')), findsNothing);
    });

    testWidgets('picks values of a list field and filters the library', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await addFilter(tester, 'genre');

      expect(find.byKey(const Key('filter-option-Platformer')), findsOneWidget);
      await pick(tester, 'RPG');
      await closePopover(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('filter-token-genre')),
          matching: find.text('RPG'),
        ),
        findsOneWidget,
      );
      expect(cover('Elden Ring'), findsOneWidget);
      expect(cover('Disco Elysium'), findsOneWidget);
      expect(cover('Celeste'), findsNothing);
      expect(inLibrary(find.text('2 of 4 games')), findsOneWidget);
    });

    testWidgets('a game matches when it has any of the picked values', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await addFilter(tester, 'platform');

      await pick(tester, 'Switch');
      await closePopover(tester);

      expect(cover('Celeste'), findsOneWidget);
      expect(cover('Portal 2'), findsOneWidget);
      expect(cover('Elden Ring'), findsNothing);
    });

    testWidgets('filters by category', (tester) async {
      await pumpLibrary(tester, backlog());
      await addFilter(tester, 'category');

      await pick(tester, 'Co-op nights');
      await closePopover(tester);

      expect(cover('Portal 2'), findsOneWidget);
      expect(cover('Celeste'), findsNothing);
    });

    testWidgets('filters by a range with a minimum and a maximum', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await addFilter(tester, 'playtime');

      await tester.enterText(find.byKey(const Key('range-min')), '30');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(find.byKey(const Key('range-max')), '60');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await closePopover(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('filter-token-playtime')),
          matching: find.text('30 to 60 h'),
        ),
        findsOneWidget,
      );
      expect(cover('Elden Ring'), findsOneWidget);
      expect(cover('Disco Elysium'), findsNothing);
      expect(cover('Celeste'), findsOneWidget);
    });

    testWidgets('takes a range of the full slider as no filter', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await addFilter(tester, 'interest');

      await tester.enterText(find.byKey(const Key('range-min')), '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(find.byKey(const Key('range-max')), '10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await closePopover(tester);

      expect(find.byKey(const Key('filter-token-interest')), findsNothing);
    });
  });

  group('tokens', () {
    testWidgets('are removed with their x', (tester) async {
      await pumpLibrary(tester, backlog());
      await addFilter(tester, 'genre');
      await pick(tester, 'RPG');
      await closePopover(tester);

      await tapKey(tester, 'filter-remove-genre');

      expect(find.byKey(const Key('filter-token-genre')), findsNothing);
      expect(cover('Celeste'), findsOneWidget);
    });

    testWidgets('are edited by tapping their text', (tester) async {
      await pumpLibrary(tester, backlog());
      await addFilter(tester, 'genre');
      await pick(tester, 'RPG');
      await closePopover(tester);

      await tapKey(tester, 'filter-token-genre');
      await pick(tester, 'Puzzle');
      await pick(tester, 'RPG');
      await closePopover(tester);

      expect(cover('Portal 2'), findsOneWidget);
      expect(cover('Elden Ring'), findsNothing);
    });
  });

  group('owned only and reset', () {
    testWidgets('owned only keeps the games that are owned', (tester) async {
      await pumpLibrary(tester, backlog());

      await tapKey(tester, 'owned-only');

      expect(cover('Elden Ring'), findsOneWidget);
      expect(cover('Portal 2'), findsOneWidget);
      expect(cover('Celeste'), findsNothing);
      expect(inLibrary(find.text('2 of 4 games')), findsOneWidget);
    });

    testWidgets('reset clears the filters and keeps the search text', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      await tester.enterText(find.byKey(const Key('search-field')), 'e');
      await tester.pumpAndSettle();
      await addFilter(tester, 'genre');
      await pick(tester, 'RPG');
      await closePopover(tester);
      await tapKey(tester, 'owned-only');

      await tapKey(tester, 'filter-reset');

      expect(find.byKey(const Key('filter-token-genre')), findsNothing);
      expect(find.byKey(const Key('filter-reset')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('search-field')))
            .controller!
            .text,
        'e',
      );
      expect(cover('Celeste'), findsOneWidget);
      expect(cover('Disco Elysium'), findsOneWidget);
    });
  });

  group('the search field', () {
    testWidgets('filters by title, ignoring case', (tester) async {
      await pumpLibrary(tester, backlog());

      await tester.enterText(find.byKey(const Key('search-field')), 'PORTAL');
      await tester.pumpAndSettle();

      expect(cover('Portal 2'), findsOneWidget);
      expect(cover('Celeste'), findsNothing);
      expect(inLibrary(find.text('1 of 4 games')), findsOneWidget);
    });

    testWidgets('does not count as an active filter', (tester) async {
      await pumpLibrary(tester, backlog());

      await tester.enterText(find.byKey(const Key('search-field')), 'portal');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-reset')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('status-bar')),
          matching: find.text('1 of 4 games'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the status bar', () {
    testWidgets('shows the games and the number of active filters', (
      tester,
    ) async {
      await pumpLibrary(tester, backlog());
      expect(
        find.descendant(
          of: find.byKey(const Key('status-bar')),
          matching: find.text('4 of 4 games'),
        ),
        findsOneWidget,
      );

      await addFilter(tester, 'genre');
      await pick(tester, 'RPG');
      await closePopover(tester);
      await tapKey(tester, 'owned-only');

      expect(
        find.descendant(
          of: find.byKey(const Key('status-bar')),
          matching: find.text('1 of 4 games · 2 filters'),
        ),
        findsOneWidget,
      );
    });
  });

  group('leaving the library', () {
    testWidgets('clears the counts of the status bar', (tester) async {
      final container = await pumpLibrary(tester, backlog());
      expect(
        find.descendant(
          of: find.byKey(const Key('status-bar')),
          matching: find.text('4 of 4 games'),
        ),
        findsOneWidget,
      );

      container.read(routerProvider).go(AppRoutes.steam);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('status-bar')),
          matching: find.textContaining('games'),
        ),
        findsNothing,
      );
    });
  });

  group('across the session', () {
    testWidgets('filters survive leaving the library and coming back', (
      tester,
    ) async {
      final container = await pumpLibrary(tester, backlog());
      await addFilter(tester, 'genre');
      await pick(tester, 'RPG');
      await closePopover(tester);

      container.read(routerProvider).go(AppRoutes.home);
      await tester.pumpAndSettle();
      container.read(routerProvider).go(AppRoutes.library);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-token-genre')), findsOneWidget);
      expect(cover('Celeste'), findsNothing);
    });
  });
}
