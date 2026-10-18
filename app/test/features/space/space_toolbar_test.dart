import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/data/igdb_sync_api.dart';
import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/data/steam_api.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../igdb_sync/igdb_sync_sheet_test.dart' show FakeIgdbSyncApi;
import '../library/library_page_test.dart' show game, pumpLibrary;
import '../steam/steam_page_test.dart' show FakeSteamApi;
import 'space_page_test.dart' show FakeSpaceApi, together;

class Opened {
  Opened(this.container, this.steam, this.igdb, this.backlog);

  final ProviderContainer container;
  final FakeSteamApi steam;
  final FakeIgdbSyncApi igdb;
  final FakeBacklogApi backlog;
}

Future<Opened> openSpace(
  WidgetTester tester, {
  String steamId = '76561197960287930',
  String location = AppRoutes.space,
}) async {
  final steam = FakeSteamApi();
  final igdb = FakeIgdbSyncApi();
  final backlog = FakeBacklogApi(entries: [game(1, 'It Takes Two')]);
  final container = await pumpLibrary(
    tester,
    backlog,
    height: 1100,
    overrides: [
      sessionUserProvider.overrideWithValue(
        SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          steamId: steamId,
        ),
      ),
      spaceApiProvider.overrideWithValue(FakeSpaceApi(together)),
      steamApiProvider.overrideWithValue(steam),
      igdbSyncApiProvider.overrideWithValue(igdb),
    ],
  );
  container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
  return Opened(container, steam, igdb, backlog);
}

Rect rectOf(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(Key(key)));

void main() {
  testWidgets('has the tools of the library next to Select', (tester) async {
    await openSpace(tester);

    for (final key in [
      'select-toggle',
      'steam-sync-button',
      'igdb-sync-button',
      'random-pull-button',
      'duplicates-button',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('has no Steam sync without a Steam ID', (tester) async {
    await openSpace(tester, steamId: '');

    expect(find.byKey(const Key('steam-sync-button')), findsNothing);
    expect(find.byKey(const Key('igdb-sync-button')), findsOneWidget);
  });

  testWidgets('lays out the header like the library', (tester) async {
    await openSpace(tester);
    final add = rectOf(tester, 'add-game-button');
    final search = tester.getRect(find.byKey(const Key('search-field')));
    final heading = rectOf(tester, 'library-heading');
    final pane = tester.getRect(find.byKey(const Key('main-content')));

    expect(pane.right - add.right, closeTo(28, 0.5));
    expect(
      search.center.dx,
      closeTo((heading.right + 24 + add.left - 12) / 2, 2),
    );
    expect(search.left, greaterThan(heading.right));
    expect(search.right, lessThan(add.left));
    expect(
      (search.center.dy - add.center.dy).abs(),
      lessThan(2),
      reason: 'search and add game are on one line',
    );
  });

  testWidgets('stays usable in a narrow window', (tester) async {
    await openSpace(tester);
    tester.view.physicalSize = const Size(760, 1100);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final pane = tester.getRect(find.byKey(const Key('main-content')));
    final add = rectOf(tester, 'add-game-button');
    expect(add.right, lessThanOrEqualTo(pane.right));
    expect(find.byKey(const Key('search-field')), findsOneWidget);
    expect(find.byKey(const Key('igdb-sync-button')), findsOneWidget);
  });

  testWidgets('the library header keeps the same gutter and centre', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      FakeBacklogApi(entries: [game(1, 'Hades')]),
      height: 1100,
    );
    final add = rectOf(tester, 'add-game-button');
    final search = tester.getRect(find.byKey(const Key('search-field')));
    final heading = rectOf(tester, 'library-heading');
    final pane = tester.getRect(find.byKey(const Key('main-content')));

    expect(pane.right - add.right, closeTo(28, 0.5));
    expect(
      search.center.dx,
      closeTo((heading.right + 24 + add.left - 12) / 2, 2),
    );
  });

  testWidgets('the Steam sync runs and refreshes the entries of the space', (
    tester,
  ) async {
    final opened = await openSpace(tester);
    opened.backlog.calls.clear();

    await tester.tap(find.byKey(const Key('steam-sync-button')));
    await tester.pump();
    expect(opened.steam.calls, ['sync-playtimes']);
    opened.steam.stream.add(const SseDone(<Object?>[{}]));
    await tester.pumpAndSettle();

    expect(opened.backlog.calls, contains('entries 4'));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the IGDB sync counts and syncs the games of the space', (
    tester,
  ) async {
    final opened = await openSpace(tester);

    await tester.tap(find.byKey(const Key('igdb-sync-button')));
    await tester.pumpAndSettle();
    expect(opened.igdb.countedFor, contains(4));
    expect(opened.igdb.countedFor, isNot(contains(null)));

    await tester.tap(find.byKey(const Key('igdb-sync-start')));
    await tester.pump();
    expect(opened.igdb.syncedFor, [4]);

    opened.backlog.calls.clear();
    opened.igdb.controller.add(const SseDone(<Object?>[{}]));
    await tester.pumpAndSettle();
    expect(opened.backlog.calls, contains('entries 4'));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Find duplicates looks at the games of the space', (
    tester,
  ) async {
    await openSpace(tester);

    await tester.tap(find.byKey(const Key('duplicates-button')));
    await tester.pumpAndSettle();

    expect(find.text('Duplicate Games'), findsOneWidget);
  });
}
