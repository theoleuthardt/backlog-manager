import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/features/add_game/add_game_sheet.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show backlog, pumpLibrary;

GameSearchResult found(
  int id,
  String title, {
  List<String> genres = const ['Roguelike'],
  List<String> platforms = const ['PC'],
  double main = 22,
}) => GameSearchResult(
  id: id,
  title: title,
  genres: genres,
  platforms: platforms,
  mainStory: main,
  mainStoryWithExtras: 48,
  completionist: 95,
);

Future<(ProviderContainer, FakeGamesApi)> openSheet(
  WidgetTester tester, {
  void Function(FakeGamesApi games)? setUp,
}) async {
  final games = FakeGamesApi();
  setUp?.call(games);
  final container = await pumpLibrary(
    tester,
    FakeBacklogApi(entries: backlog),
    height: 900,
    overrides: [gamesApiProvider.overrideWithValue(games)],
  );
  await tester.tap(find.text('Add game').first);
  await tester.pumpAndSettle();
  return (container, games);
}

Future<void> typeSearch(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pump();
}

Future<void> settleSearch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

Finder inSheet(Finder matching) =>
    find.descendant(of: find.byType(AddGameSheet), matching: matching);

Uri location(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri;

void main() {
  testWidgets('opens from the Add game button', (tester) async {
    await openSheet(tester);

    expect(find.text('Search for a game'), findsOneWidget);
    expect(find.text('Create it as a custom game'), findsOneWidget);
  });

  testWidgets('waits 800 ms after typing before it searches', (tester) async {
    final (_, games) = await openSheet(
      tester,
      setUp: (g) => g.onSearch = (term, deep) async => [found(1, 'Hades')],
    );

    await typeSearch(tester, 'hades');
    expect(find.text('Searching for game...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(games.calls.where((c) => c.startsWith('search')), isEmpty);

    await settleSearch(tester);

    expect(games.calls, contains('search hades'));
    expect(find.text('Searching for game...'), findsNothing);
  });

  testWidgets('lists the results as a table with the times to beat', (
    tester,
  ) async {
    await openSheet(
      tester,
      setUp: (g) => g.onSearch = (term, deep) async => [
        found(1, 'Hades', genres: ['Roguelike', 'Action']),
        found(2, 'Hades II', main: 30),
      ],
    );

    await typeSearch(tester, 'hades');
    await settleSearch(tester);

    expect(inSheet(find.text('Hades')), findsOneWidget);
    expect(inSheet(find.text('Hades II')), findsOneWidget);
    expect(inSheet(find.text('Roguelike, Action')), findsOneWidget);
    expect(inSheet(find.text('22 / 48 / 95 h')), findsOneWidget);
    expect(inSheet(find.text('30 / 48 / 95 h')), findsOneWidget);
  });

  testWidgets('Continue needs a chosen game and then opens the creation tool', (
    tester,
  ) async {
    final (container, _) = await openSheet(
      tester,
      setUp: (g) => g.onSearch = (term, deep) async => [
        found(1, 'Hades'),
        found(2, 'Hades II', main: 30),
      ],
    );
    await typeSearch(tester, 'hades');
    await settleSearch(tester);
    final continueButton = find.byKey(const Key('add-continue'));
    expect(
      tester
          .widget<Opacity>(
            find
                .descendant(of: continueButton, matching: find.byType(Opacity))
                .first,
          )
          .opacity,
      lessThan(1),
    );

    await tester.tap(inSheet(find.text('Hades II')));
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Search for a game'), findsNothing);
    final uri = location(container);
    expect(uri.path, AppRoutes.creationTool);
    expect(uri.queryParameters['title'], 'Hades II');
    expect(uri.queryParameters['mainStory'], '30');
  });

  testWidgets('Enter in the field continues with the first result', (
    tester,
  ) async {
    final (container, _) = await openSheet(
      tester,
      setUp: (g) => g.onSearch = (term, deep) async => [found(1, 'Hades')],
    );
    await typeSearch(tester, 'hades');
    await settleSearch(tester);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(location(container).queryParameters['title'], 'Hades');
  });

  testWidgets('says so when nothing was found and offers a custom game', (
    tester,
  ) async {
    final (container, _) = await openSheet(tester);

    await typeSearch(tester, 'My own game');
    await settleSearch(tester);

    expect(find.text('No results found'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-custom-empty')));
    await tester.pumpAndSettle();

    final uri = location(container);
    expect(uri.path, AppRoutes.creationTool);
    expect(uri.queryParameters, {'title': 'My own game', 'custom': '1'});
  });

  testWidgets('the custom game link is there from the start', (tester) async {
    final (container, _) = await openSheet(tester);

    await tester.tap(find.byKey(const Key('add-custom')));
    await tester.pumpAndSettle();

    expect(location(container).queryParameters['custom'], '1');
  });

  testWidgets('shows the error of a failed search', (tester) async {
    await openSheet(
      tester,
      setUp: (g) =>
          g.onSearch = (term, deep) async =>
              throw const ApiException('IGDB is down'),
    );

    await typeSearch(tester, 'hades');
    await settleSearch(tester);

    expect(find.text('IGDB is down'), findsOneWidget);
  });

  testWidgets('asking twice opens one sheet', (tester) async {
    final (container, _) = await openSheet(tester);

    container.read(addGameRequestProvider.notifier).request();
    await tester.pumpAndSettle();

    expect(find.byType(AddGameSheet), findsOneWidget);
  });

  testWidgets('Enter does nothing while the search is still settling', (
    tester,
  ) async {
    final (container, _) = await openSheet(
      tester,
      setUp: (g) => g.onSearch = (term, deep) async => [found(1, 'Hades')],
    );
    await typeSearch(tester, 'hades');
    await settleSearch(tester);
    await tester.enterText(find.byType(TextField).last, 'hades ii');
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AddGameSheet), findsOneWidget);
    expect(location(container).path, isNot(AppRoutes.creationTool));
  });

  testWidgets('Esc closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Search for a game'), findsNothing);
  });

  testWidgets('golden: the add-a-game sheet', tags: 'golden', (tester) async {
    final completer = Completer<void>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete();
    });
    await openSheet(
      tester,
      setUp: (g) => g.onSearch = (term, deep) async => [
        found(
          1,
          'Hades',
          genres: ['Roguelike', 'Action'],
          platforms: ['PC', 'Switch'],
        ),
        found(2, 'Hades II', main: 30),
        found(3, 'Hades Star', genres: ['Strategy'], main: 0),
      ],
    );
    await typeSearch(tester, 'hades');
    await settleSearch(tester);
    await tester.tap(inSheet(find.text('Hades')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_game_sheet.png'),
    );
  });
}
