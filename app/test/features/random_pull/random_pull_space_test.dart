import 'dart:math';

import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/features/random_pull/random_pull_sheet.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show pumpLibrary;
import '../space/space_page_test.dart' show FakeSpaceApi, together;
import 'random_pull_sheet_test.dart' show SequenceRandom;

BacklogEntry coop(
  int id,
  String title, {
  bool owned = true,
  String status = 'In Progress',
}) => BacklogEntry(id: id, title: title, status: status, owned: owned);

Future<ProviderContainer> openSpace(
  WidgetTester tester,
  List<BacklogEntry> entries, {
  List<int> picks = const [0],
}) async {
  final container = await pumpLibrary(
    tester,
    FakeBacklogApi(entries: entries),
    height: 1100,
    overrides: [
      spaceApiProvider.overrideWithValue(FakeSpaceApi(together)),
      gamesApiProvider.overrideWithValue(FakeGamesApi()),
      randomProvider.overrideWithValue(SequenceRandom(picks)),
    ],
  );
  container.read(routerProvider).go(AppRoutes.space);
  await tester.pumpAndSettle();
  return container;
}

String locationOf(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

void main() {
  testWidgets('the Shared Space has the random pull button', (tester) async {
    await openSpace(tester, [coop(1, 'It Takes Two')]);

    expect(find.byKey(const Key('random-pull-button')), findsOneWidget);
  });

  testWidgets('pulls a game of the space the user owns and still has to play', (
    tester,
  ) async {
    await openSpace(tester, [
      coop(1, 'It Takes Two'),
      coop(2, 'Portal 2', status: 'Completed'),
      coop(3, 'Deep Rock Galactic', owned: false),
    ]);

    await tester.tap(find.byKey(const Key('random-pull-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('random-pull-start')));
    await tester.pumpAndSettle();

    expect(find.text('Random Pull'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('random-pull-title'))).data,
      'It Takes Two',
    );
    expect(find.text('1 game to choose from'), findsOneWidget);
  });

  testWidgets('says that the game comes from the Shared Space', (tester) async {
    await openSpace(tester, [coop(1, 'It Takes Two')]);

    await tester.tap(find.byKey(const Key('random-pull-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'One game of your Shared Space at random, from what your filters show.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Open Details goes to the game in the Shared Space', (
    tester,
  ) async {
    final container = await openSpace(
      tester,
      [coop(1, 'It Takes Two'), coop(2, 'Portal 2')],
      picks: [1],
    );

    await tester.tap(find.byKey(const Key('random-pull-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('random-pull-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('random-pull-open')));
    await tester.pumpAndSettle();

    expect(locationOf(container), '/space?entry=2');
  });

  testWidgets('the personal library still says it is your library', (
    tester,
  ) async {
    final container = await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [coop(1, 'Hades')]),
      height: 1100,
      overrides: [randomProvider.overrideWithValue(Random(1))],
    );
    expect(locationOf(container), isNot(contains('/space')));

    await tester.tap(find.byKey(const Key('random-pull-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'One game of your library at random, from what your filters show.',
      ),
      findsOneWidget,
    );
  });
}
