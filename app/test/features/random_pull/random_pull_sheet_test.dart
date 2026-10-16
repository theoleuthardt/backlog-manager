import 'dart:math';

import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/random_pull/random_pull_sheet.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show pumpLibrary;

class SequenceRandom implements Random {
  SequenceRandom(this.values);

  final List<int> values;
  var _next = 0;

  @override
  int nextInt(int max) => values[_next++ % values.length] % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

const hades = BacklogEntry(
  id: 1,
  title: 'Hades',
  genre: ['Roguelike', 'Action'],
  platform: ['PC'],
  status: 'In Progress',
  owned: true,
  interest: 6,
  playtime: 18,
  mainTime: 22,
);
const celeste = BacklogEntry(
  id: 2,
  title: 'Celeste',
  genre: ['Platformer'],
  platform: ['PC'],
  status: 'Not Started',
  owned: true,
  interest: 5,
);
const portal = BacklogEntry(
  id: 3,
  title: 'Portal 2',
  platform: ['PC'],
  status: 'Completed',
  owned: true,
  interest: 5,
);
const wish = BacklogEntry(
  id: 4,
  title: 'Hollow Knight',
  platform: ['PC'],
  status: 'Not Owned',
  owned: false,
  interest: 7,
);

Future<ProviderContainer> open(
  WidgetTester tester, {
  List<int> picks = const [0],
}) async {
  final container = await pumpLibrary(
    tester,
    FakeBacklogApi(entries: [hades, celeste, portal, wish]),
    height: 1100,
    overrides: [randomProvider.overrideWithValue(SequenceRandom(picks))],
  );
  await tester.tap(find.byKey(const Key('random-pull-button')));
  await tester.pumpAndSettle();
  return container;
}

Finder get sheetTitle => find.byKey(const Key('random-pull-title'));

String titleText(WidgetTester tester) =>
    tester.widget<Text>(sheetTitle).data ?? '';

void main() {
  testWidgets('opens from the library toolbar and shows a game', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Random Pull'), findsOneWidget);
    expect(sheetTitle, findsOneWidget);
    expect(
      ['Hades', 'Celeste'],
      contains(titleText(tester)),
      reason: 'only unfinished, owned games are in the pool',
    );
  });

  testWidgets('says how many games it chooses from', (tester) async {
    await open(tester);

    expect(find.text('2 games to choose from'), findsOneWidget);
  });

  testWidgets('shows what the game is: status, hours and genres', (
    tester,
  ) async {
    await open(tester, picks: [1]);

    expect(titleText(tester), 'Hades');
    expect(find.text('In Progress'), findsWidgets);
    expect(find.textContaining('18 of 22 h'), findsOneWidget);
    expect(find.textContaining('Roguelike'), findsOneWidget);
  });

  testWidgets('Pull Again picks another game, never the same twice', (
    tester,
  ) async {
    await open(tester, picks: [0, 0, 0]);
    final first = titleText(tester);

    await tester.tap(find.byKey(const Key('random-pull-again')));
    await tester.pumpAndSettle();

    expect(titleText(tester), isNot(first));
  });

  testWidgets('can include finished games', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('random-pull-include-finished')));
    await tester.pumpAndSettle();

    expect(find.text('3 games to choose from'), findsOneWidget);
  });

  testWidgets('never offers a game that is not owned', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('random-pull-include-finished')));
    await tester.pumpAndSettle();

    expect(find.text('4 games to choose from'), findsNothing);
  });

  testWidgets('chooses only from the games the filters show', (tester) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [hades, celeste, portal, wish]),
      height: 1100,
      overrides: [
        randomProvider.overrideWithValue(SequenceRandom([0])),
      ],
    );
    container.read(filtersProvider.notifier).setSearch('celeste');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('random-pull-button')));
    await tester.pumpAndSettle();

    expect(titleText(tester), 'Celeste');
    expect(find.text('1 game to choose from'), findsOneWidget);
    expect(find.byKey(const Key('random-pull-again')), findsNothing);
  });

  testWidgets('says so when no game fits and offers the finished ones', (
    tester,
  ) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [hades, celeste, portal, wish]),
      height: 1100,
    );
    container.read(filtersProvider.notifier).setSearch('portal');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('random-pull-button')));
    await tester.pumpAndSettle();

    expect(sheetTitle, findsNothing);
    expect(find.text('No game to pull'), findsOneWidget);
    await tester.tap(find.byKey(const Key('random-pull-include-finished')));
    await tester.pumpAndSettle();
    expect(titleText(tester), 'Portal 2');
  });

  testWidgets('Open Details goes to the game in the library', (tester) async {
    final container = await open(tester, picks: [1]);

    await tester.tap(find.byKey(const Key('random-pull-open')));
    await tester.pumpAndSettle();

    expect(find.text('Random Pull'), findsNothing);
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString(),
      '/library?entry=1',
    );
  });

  testWidgets('a request from the palette opens it too', (tester) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [hades, celeste]),
      height: 1100,
    );

    container.read(randomPullRequestProvider.notifier).request();
    await tester.pumpAndSettle();

    expect(find.text('Random Pull'), findsOneWidget);
  });

  testWidgets('golden: the random pull', tags: 'golden', (tester) async {
    await open(tester, picks: [1]);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/random_pull.png'),
    );
  });
}
