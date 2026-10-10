import 'dart:async';

import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/features/add_game/wrong_game_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show backlog, pumpLibrary;

GameSearchResult found(int id, String title) => GameSearchResult(
  id: id,
  title: title,
  genres: const ['Party'],
  platforms: const ['PC'],
  mainStory: 12,
  mainStoryWithExtras: 20,
  completionist: 40,
);

class Opened {
  GameSearchResult? chosen;
  bool closed = false;
}

Future<(FakeGamesApi, Opened)> openWrongGame(
  WidgetTester tester, {
  String query = 'Overcooked',
  void Function(FakeGamesApi games)? setUp,
}) async {
  final games = FakeGamesApi();
  setUp?.call(games);
  final opened = Opened();
  await pumpLibrary(
    tester,
    FakeBacklogApi(entries: backlog),
    height: 900,
    overrides: [gamesApiProvider.overrideWithValue(games)],
  );
  final context = tester.element(find.byKey(const Key('main-content')));
  unawaited(
    showWrongGameSheet(context, initialQuery: query).then((result) {
      opened
        ..chosen = result
        ..closed = true;
    }),
  );
  await tester.pumpAndSettle();
  return (games, opened);
}

Finder inSheet(Finder matching) =>
    find.descendant(of: find.byType(WrongGameSheet), matching: matching);

void main() {
  testWidgets('searches for the title of the entry at once', (tester) async {
    final (games, _) = await openWrongGame(
      tester,
      setUp: (g) => g.onSearch = (t, d) async => [found(1, 'Overcooked!')],
    );

    expect(games.calls, contains('search Overcooked'));
    expect(find.text('Find the right game'), findsOneWidget);
    expect(inSheet(find.text('Overcooked!')), findsOneWidget);
    expect(
      inSheet(find.text('Main 12 h · +Extra 20 h · Completionist 40 h')),
      findsOneWidget,
    );
  });

  testWidgets('waits 300 ms after typing before it searches again', (
    tester,
  ) async {
    final (games, _) = await openWrongGame(tester);

    await tester.enterText(find.byType(TextField).last, 'Crash');
    await tester.pump(const Duration(milliseconds: 200));
    expect(games.calls.where((c) => c == 'search Crash'), isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(games.calls, contains('search Crash'));
  });

  testWidgets('says so when there is no result', (tester) async {
    await openWrongGame(tester);

    expect(find.text('No results found.'), findsOneWidget);
  });

  testWidgets('Use this game needs a chosen result and returns it', (
    tester,
  ) async {
    final (_, opened) = await openWrongGame(
      tester,
      setUp: (g) => g.onSearch = (t, d) async => [
        found(1, 'Overcooked!'),
        found(2, 'Overcooked! 2'),
      ],
    );

    await tester.tap(inSheet(find.text('Overcooked! 2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wrong-use')));
    await tester.pumpAndSettle();

    expect(opened.closed, isTrue);
    expect(opened.chosen?.id, 2);
  });

  testWidgets('Cancel closes without a result', (tester) async {
    final (_, opened) = await openWrongGame(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(opened.closed, isTrue);
    expect(opened.chosen, isNull);
  });

  group('search more', () {
    FakeGamesApi? games0;

    Future<Opened> open(WidgetTester tester) async {
      final (games, opened) = await openWrongGame(
        tester,
        setUp: (g) => g.onSearch = (term, deep) async => deep
            ? [found(1, 'Overcooked!'), found(3, 'Overcooked! All You Can Eat')]
            : [found(1, 'Overcooked!')],
      );
      games0 = games;
      return opened;
    }

    testWidgets('asks for the deep search and marks what only it found', (
      tester,
    ) async {
      await open(tester);
      expect(inSheet(find.byKey(const Key('deeper-marker'))), findsNothing);

      await tester.tap(find.byKey(const Key('wrong-search-more')));
      await tester.pumpAndSettle();

      expect(games0!.calls, contains('search Overcooked deep'));
      expect(inSheet(find.text('Overcooked! All You Can Eat')), findsOneWidget);
      expect(inSheet(find.byKey(const Key('deeper-marker'))), findsOneWidget);
      expect(find.text('Found by deeper search'), findsOneWidget);
      expect(find.byKey(const Key('wrong-search-more')), findsNothing);
    });

    testWidgets('goes back to the normal search when the query changes', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('wrong-search-more')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Overcooked 2');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wrong-search-more')), findsOneWidget);
      expect(find.byKey(const Key('deeper-marker')), findsNothing);
    });

    testWidgets('explains what a deeper search does', (tester) async {
      await open(tester);

      expect(
        find.text('Searching deeper also tries other spellings and bundles.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('golden: find the right game', tags: 'golden', (tester) async {
    await openWrongGame(
      tester,
      setUp: (g) => g.onSearch = (term, deep) async => deep
          ? [found(1, 'Overcooked! All You Can Eat'), found(2, 'Overcooked! 2')]
          : [found(2, 'Overcooked! 2')],
    );
    await tester.tap(find.byKey(const Key('wrong-search-more')));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Overcooked! All You Can Eat')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/wrong_game_sheet.png'),
    );
  });
}
