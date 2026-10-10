import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/features/add_game/cover_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show backlog, pumpLibrary;

class Picked {
  String? url;
  bool closed = false;
}

Future<(FakeGamesApi, Picked)> openPicker(
  WidgetTester tester, {
  int? steamAppId = 620,
  String query = 'Portal 2',
  bool settle = true,
  void Function(FakeGamesApi games)? setUp,
}) async {
  final games = FakeGamesApi();
  setUp?.call(games);
  final picked = Picked();
  await pumpLibrary(
    tester,
    FakeBacklogApi(entries: backlog),
    height: 900,
    overrides: [gamesApiProvider.overrideWithValue(games)],
  );
  final context = tester.element(find.byKey(const Key('main-content')));
  unawaited(
    showCoverPicker(context, initialQuery: query, steamAppId: steamAppId).then((
      url,
    ) {
      picked
        ..url = url
        ..closed = true;
    }),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return (games, picked);
}

void main() {
  testWidgets('shows the covers of the Steam App ID', (tester) async {
    final (games, _) = await openPicker(
      tester,
      setUp: (g) => g.onCovers = (id) async => [
        'https://cdn.example/a.png',
        'https://cdn.example/b.png',
      ],
    );

    expect(find.text('SteamGridDB Covers'), findsOneWidget);
    expect(games.calls, ['covers 620']);
    expect(find.byKey(const Key('cover-grid')), findsOneWidget);
    expect(find.bySemanticsLabel('Cover option'), findsNWidgets(2));
  });

  testWidgets('picking a cover returns its address', (tester) async {
    final (_, picked) = await openPicker(
      tester,
      setUp: (g) => g.onCovers = (id) async => [
        'https://cdn.example/a.png',
        'https://cdn.example/b.png',
      ],
    );

    await tester.tap(find.bySemanticsLabel('Cover option').last);
    await tester.pumpAndSettle();

    expect(picked.closed, isTrue);
    expect(picked.url, 'https://cdn.example/b.png');
  });

  testWidgets('says so when SteamGridDB has no cover', (tester) async {
    await openPicker(tester);

    expect(
      find.text('No SteamGridDB covers available for this game.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the error of a failed request', (tester) async {
    await openPicker(
      tester,
      setUp: (g) =>
          g.onCovers = (id) async =>
              throw const ApiException('SteamGridDB is down'),
    );

    expect(find.text('SteamGridDB is down'), findsOneWidget);
  });

  testWidgets('without a Steam App ID it starts with a search for the title', (
    tester,
  ) async {
    final (games, _) = await openPicker(
      tester,
      steamAppId: null,
      setUp: (g) => g.onGridSearch = (term) async => [
        const SteamGridDbMatch(id: 7, name: 'Portal 2'),
      ],
    );

    expect(games.calls, ['grid-search Portal 2']);
    expect(find.byKey(const Key('cover-matches')), findsOneWidget);
  });

  testWidgets('without a Steam App ID and a title it explains what to do', (
    tester,
  ) async {
    await openPicker(tester, steamAppId: null, query: '');

    expect(
      find.text(
        'No Steam App ID for this entry - search above to find covers for it '
        'on SteamGridDB.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking a search result shows the covers of that game', (
    tester,
  ) async {
    final (games, picked) = await openPicker(
      tester,
      steamAppId: null,
      setUp: (g) {
        g.onGridSearch = (term) async => [
          const SteamGridDbMatch(id: 7, name: 'Portal 2'),
        ];
        g.onCoversById = (id) async => ['https://cdn.example/portal.png'];
      },
    );

    await tester.tap(find.bySemanticsLabel('Portal 2'));
    await tester.pumpAndSettle();

    expect(games.calls, contains('covers-by-id 7'));
    expect(find.byKey(const Key('cover-matches')), findsNothing);
    await tester.tap(find.bySemanticsLabel('Cover option'));
    await tester.pumpAndSettle();
    expect(picked.url, 'https://cdn.example/portal.png');
  });

  testWidgets('says so when the search finds no game', (tester) async {
    await openPicker(tester, steamAppId: null);

    expect(find.byKey(const Key('cover-no-match')), findsOneWidget);
    expect(find.text('No game found for "Portal 2".'), findsOneWidget);
  });

  testWidgets('shows the error of a failed search', (tester) async {
    await openPicker(
      tester,
      steamAppId: null,
      setUp: (g) =>
          g.onGridSearch = (term) async =>
              throw const ApiException('SteamGridDB search is down'),
    );

    expect(find.text('SteamGridDB search is down'), findsOneWidget);
  });

  testWidgets('shows that the search is running', (tester) async {
    final pending = Completer<List<SteamGridDbMatch>>();
    await openPicker(
      tester,
      steamAppId: null,
      settle: false,
      setUp: (g) => g.onGridSearch = (term) => pending.future,
    );

    expect(find.byKey(const Key('cover-searching')), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('a search for another title waits 300 ms', (tester) async {
    final (games, _) = await openPicker(tester);

    await tester.enterText(find.byType(TextField).last, 'Celeste');
    await tester.pump(const Duration(milliseconds: 200));
    expect(games.calls, isNot(contains('grid-search Celeste')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(games.calls, contains('grid-search Celeste'));
  });

  testWidgets('golden: the cover picker', tags: 'golden', (tester) async {
    await openPicker(
      tester,
      setUp: (g) => g.onCovers = (id) async => [
        for (var i = 0; i < 4; i++) 'https://cdn.example/$i.png',
      ],
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cover_picker_sheet.png'),
    );
  });
}
