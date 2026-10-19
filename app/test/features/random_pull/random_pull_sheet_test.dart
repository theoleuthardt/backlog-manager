import 'dart:math';

import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/filter_providers.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
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

Future<ProviderContainer> openChoosing(
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

Future<void> pull(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('random-pull-start')));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> open(
  WidgetTester tester, {
  List<int> picks = const [0],
}) async {
  final container = await openChoosing(tester, picks: picks);
  await pull(tester);
  return container;
}

Finder group(String key) => find.byKey(Key('random-pull-group-check-$key'));

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
    await openChoosing(tester);

    await tester.tap(find.byKey(const Key('random-pull-include-finished')));
    await tester.pumpAndSettle();

    expect(find.text('3 games to choose from'), findsOneWidget);
  });

  testWidgets('never offers a game that is not owned', (tester) async {
    await openChoosing(tester);
    await tester.tap(find.byKey(const Key('random-pull-include-finished')));
    await tester.pumpAndSettle();

    expect(find.text('3 games to choose from'), findsOneWidget);
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
    await pull(tester);

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
    expect(
      tester
          .widget<ShelfButton>(find.byKey(const Key('random-pull-start')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('random-pull-include-finished')));
    await tester.pumpAndSettle();
    await pull(tester);
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

  testWidgets('pulls another game when the one shown leaves the pool', (
    tester,
  ) async {
    final container = await open(tester, picks: [0]);
    expect(titleText(tester), 'Celeste');

    await container
        .read(entriesProvider(null).notifier)
        .updateEntry(2, const EntryUpdate(status: 'Completed'));
    await tester.pumpAndSettle();

    expect(titleText(tester), 'Hades');
    expect(find.text('1 game to choose from'), findsOneWidget);
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

  testWidgets('asks which groups take part before it pulls', (tester) async {
    await openChoosing(tester);

    expect(find.text('Groups that take part'), findsOneWidget);
    expect(sheetTitle, findsNothing);
    expect(group('status:In Progress'), findsOneWidget);
    expect(group('status:Not Started'), findsOneWidget);
    expect(find.text('2 games to choose from'), findsOneWidget);
  });

  testWidgets('shows how many games every group offers', (tester) async {
    await openChoosing(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('random-pull-group-status:In Progress')),
        matching: find.text('1 game'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('random-pull-group-status:Completed')),
        matching: find.text('0 games'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a group that is left out takes its games out of the pull', (
    tester,
  ) async {
    await openChoosing(tester, picks: [0]);

    await tester.tap(group('status:Not Started'));
    await tester.pumpAndSettle();
    expect(find.text('1 game to choose from'), findsOneWidget);
    await pull(tester);

    expect(titleText(tester), 'Hades');
    expect(find.byKey(const Key('random-pull-again')), findsNothing);
  });

  testWidgets('None leaves every group out and All brings them back', (
    tester,
  ) async {
    await openChoosing(tester);

    await tester.tap(find.byKey(const Key('random-pull-groups-none')));
    await tester.pumpAndSettle();
    expect(find.text('No game to pull'), findsOneWidget);
    expect(
      tester
          .widget<ShelfButton>(find.byKey(const Key('random-pull-start')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('random-pull-groups-all')));
    await tester.pumpAndSettle();
    expect(find.text('2 games to choose from'), findsOneWidget);
  });

  testWidgets('a slot machine reel spins before the game is shown', (
    tester,
  ) async {
    await openChoosing(tester);

    await tester.tap(find.byKey(const Key('random-pull-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const Key('random-pull-reel')), findsOneWidget);
    expect(sheetTitle, findsNothing);
    expect(find.byKey(const Key('random-pull-open')), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('random-pull-reel')), findsNothing);
    expect(sheetTitle, findsOneWidget);
  });

  testWidgets('Pull Again spins the reel again', (tester) async {
    await open(tester, picks: [0, 0, 0]);

    await tester.tap(find.byKey(const Key('random-pull-again')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('random-pull-reel')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(sheetTitle, findsOneWidget);
  });

  testWidgets('shows the game at once when the system asks for less motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openChoosing(tester);

    await tester.tap(find.byKey(const Key('random-pull-start')));
    await tester.pump();
    await tester.pump();

    expect(sheetTitle, findsOneWidget);
  });

  testWidgets('Change groups goes back and keeps the choice', (tester) async {
    await openChoosing(tester);
    await tester.tap(group('status:Not Started'));
    await tester.pumpAndSettle();
    await pull(tester);

    await tester.tap(find.byKey(const Key('random-pull-change-groups')));
    await tester.pumpAndSettle();

    expect(find.text('Groups that take part'), findsOneWidget);
    expect(find.text('1 game to choose from'), findsOneWidget);
    expect(
      tester.widget<ShelfCheckbox>(group('status:Not Started')).value,
      isFalse,
    );
  });

  testWidgets('golden: the random pull', tags: 'golden', (tester) async {
    await open(tester, picks: [1]);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/random_pull.png'),
    );
  });

  testWidgets('golden: the groups of the random pull', tags: 'golden', (
    tester,
  ) async {
    await openChoosing(tester);
    await tester.tap(group('status:Not Started'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/random_pull_groups.png'),
    );
  });

  testWidgets('golden: the reel of the random pull', tags: 'golden', (
    tester,
  ) async {
    await openChoosing(tester);
    await tester.tap(find.byKey(const Key('random-pull-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/random_pull_reel.png'),
    );
    await tester.pumpAndSettle();
  });
}
