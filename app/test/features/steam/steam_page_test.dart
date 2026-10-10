import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/api/sse.dart';
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/steam_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/domain/steam_sync.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show game;
import '../settings/settings_page_test.dart' show Settings, openSettings, theo;

class FakeSteamApi implements SteamApi {
  final calls = <String>[];
  late StreamController<SseEvent> stream;
  bool streamCancelled = false;
  List<SteamRow> wishlist = const [];
  Object? wishlistError;

  Stream<SseEvent> _open(String call) {
    calls.add(call);
    streamCancelled = false;
    stream = StreamController<SseEvent>(onCancel: () => streamCancelled = true);
    return stream.stream;
  }

  @override
  Stream<SseEvent> libraryPreview() => _open('library-preview');

  @override
  Future<List<SteamRow>> wishlistPreview() async {
    calls.add('wishlist-preview');
    if (wishlistError != null) throw wishlistError!;
    return wishlist;
  }

  @override
  Stream<SseEvent> importLibrary(List<int> appIds) =>
      _open('import-library $appIds');

  @override
  Stream<SseEvent> importWishlist(List<int> appIds) =>
      _open('import-wishlist $appIds');

  @override
  Stream<SseEvent> syncPlaytimes() => _open('sync-playtimes');
}

Map<String, Object?> item(
  int id,
  String title, {
  Object? playtime,
  String? image,
}) => {
  'steam_app_id': id,
  'title': title,
  'image_link': image,
  'playtime': playtime,
};

class Opened {
  Opened(this.steam, this.settings);

  final FakeSteamApi steam;
  final Settings settings;
}

Future<Opened> open(
  WidgetTester tester, {
  SessionUser user = theo,
  String location = AppRoutes.steam,
  FakeSteamApi? api,
  FakeBacklogApi? backlog,
}) async {
  final steam = api ?? FakeSteamApi();
  final settings = await openSettings(
    tester,
    user: user,
    location: location,
    overrides: [
      steamApiProvider.overrideWithValue(steam),
      backlogApiProvider.overrideWithValue(backlog ?? FakeBacklogApi()),
    ],
  );
  return Opened(steam, settings);
}

Future<void> dismissToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 6));

Future<void> loadLibrary(WidgetTester tester, Opened opened) async {
  await tester.tap(find.byKey(const Key('steam-load')));
  await tester.pump();
  opened.steam.stream.add(
    SseDone([
      item(620, 'Portal 2', playtime: '11'),
      item(1091500, 'Cyberpunk 2077', playtime: 0),
      item(782330, 'DOOM Eternal', playtime: '3.2'),
    ]),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the page', () {
    testWidgets('starts empty with a hint and a load button', (tester) async {
      await open(tester);

      expect(find.byKey(const Key('page-steam')), findsOneWidget);
      expect(find.byKey(const Key('steam-empty-hint')), findsOneWidget);
      expect(find.text('Load preview'), findsOneWidget);
      expect(
        find.text('Nothing is written until you press Import.'),
        findsOneWidget,
      );
      final segments = find.byKey(const Key('segmented-track'));
      expect(
        find.descendant(of: segments, matching: find.text('Library')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: segments, matching: find.text('Wishlist')),
        findsOneWidget,
      );
    });

    testWidgets('without a Steam ID it points to the settings', (tester) async {
      final opened = await open(
        tester,
        user: const SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
        ),
      );

      expect(find.byKey(const Key('steam-not-linked')), findsOneWidget);
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pump();
      expect(opened.steam.calls, isEmpty);

      await tester.tap(find.byKey(const Key('steam-open-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-settings')), findsOneWidget);
    });
  });

  group('the library preview', () {
    testWidgets('shows progress and a cancel that stops it', (tester) async {
      final opened = await open(tester);
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pump();
      expect(find.text('Checking...'), findsOneWidget);

      opened.steam.stream.add(const SseProgress(300, 1284));
      await tester.pump();
      expect(find.text('300 of 1,284 checked'), findsOneWidget);

      await tester.tap(find.byKey(const Key('steam-cancel')));
      await tester.pumpAndSettle();

      expect(opened.steam.streamCancelled, isTrue);
      expect(find.text('Preview cancelled'), findsOneWidget);
      expect(find.text('Load preview'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('lists the games with app id and playtime', (tester) async {
      final opened = await open(tester);

      await loadLibrary(tester, opened);

      expect(opened.steam.calls, ['library-preview']);
      expect(find.text('3 new games from your library'), findsOneWidget);
      expect(find.text('Portal 2'), findsOneWidget);
      expect(find.text('620'), findsOneWidget);
      expect(find.text('11 h'), findsOneWidget);
      expect(find.text('0 h'), findsOneWidget);
      expect(find.text('3.2 h'), findsOneWidget);
      expect(find.text('3 of 3 selected'), findsOneWidget);
      expect(find.text('Import 3 games'), findsOneWidget);
      expect(find.text('Reload preview'), findsOneWidget);
    });

    testWidgets('copes with a server that sends no playtime', (tester) async {
      final opened = await open(tester);
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pump();

      opened.steam.stream.add(SseDone([item(620, 'Portal 2')]));
      await tester.pumpAndSettle();

      expect(find.text('Portal 2'), findsOneWidget);
      expect(find.textContaining(' h'), findsNothing);
    });

    testWidgets('says so when there is nothing new', (tester) async {
      final opened = await open(tester);
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pump();

      opened.steam.stream.add(const SseDone(<Object?>[]));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nothing new to import - your backlog already has everything.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('steam-import')), findsNothing);
    });

    testWidgets('shows the message of the server on an error', (tester) async {
      final opened = await open(tester);
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pump();

      opened.steam.stream.add(const SseError('Steam is not reachable'));
      await tester.pumpAndSettle();

      expect(find.text('Steam is not reachable'), findsOneWidget);
      expect(find.text('Load preview'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('the filter narrows the list by title or app id', (
      tester,
    ) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);

      await tester.enterText(find.byType(TextField).last, 'doom');
      await tester.pumpAndSettle();
      expect(find.text('DOOM Eternal'), findsOneWidget);
      expect(find.text('Portal 2'), findsNothing);

      await tester.enterText(find.byType(TextField).last, '1091');
      await tester.pumpAndSettle();
      expect(find.text('Cyberpunk 2077'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steam-no-match')), findsOneWidget);
    });
  });

  group('choosing rows', () {
    testWidgets('a tap checks and unchecks a row', (tester) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);

      await tester.tap(find.text('Portal 2'));
      await tester.pump();

      expect(find.text('2 of 3 selected'), findsOneWidget);
      expect(find.text('Import 2 games'), findsOneWidget);

      await tester.tap(find.text('Portal 2'));
      await tester.pump();
      expect(find.text('3 of 3 selected'), findsOneWidget);
    });

    testWidgets('Select none and Select all', (tester) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);

      await tester.tap(find.byKey(const Key('steam-select-none')));
      await tester.pump();
      expect(find.text('0 of 3 selected'), findsOneWidget);
      final off = tester.widget<ShelfButton>(
        find.byKey(const Key('steam-import')),
      );
      expect(off.onPressed, isNull);

      await tester.tap(find.byKey(const Key('steam-select-all')));
      await tester.pump();
      expect(find.text('3 of 3 selected'), findsOneWidget);
    });

    testWidgets('select none and all follow the filter', (tester) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);

      await tester.enterText(find.byType(TextField).last, 'portal');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('steam-select-none')));
      await tester.pump();

      expect(find.text('2 of 3 selected'), findsOneWidget);
    });
  });

  group('importing the library', () {
    testWidgets('imports only the checked games and reports the result', (
      tester,
    ) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);
      await tester.tap(find.text('Portal 2'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('steam-import')));
      await tester.pump();
      expect(opened.steam.calls.last, 'import-library [1091500, 782330]');
      expect(find.text('Importing...'), findsOneWidget);

      opened.steam.stream.add(const SseProgress(1, 2));
      await tester.pump();
      expect(find.text('1/2'), findsOneWidget);

      opened.steam.stream.add(const SseDone(<Object?>[{}, {}]));
      await tester.pumpAndSettle();

      expect(
        find.text('Imported 2 games from your Steam library'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('steam-empty-hint')), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('says so when nothing was new', (tester) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);
      await tester.tap(find.byKey(const Key('steam-import')));
      await tester.pump();

      opened.steam.stream.add(const SseDone(<Object?>[]));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No new games to import, your backlog already has everything',
        ),
        findsOneWidget,
      );
      await dismissToast(tester);
    });

    testWidgets('a cancelled import keeps the preview', (tester) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);
      await tester.tap(find.byKey(const Key('steam-import')));
      await tester.pump();
      opened.steam.stream.add(const SseProgress(1, 3));
      await tester.pump();

      await tester.tap(find.byKey(const Key('steam-import-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Import cancelled'), findsOneWidget);
      expect(find.text('Import 3 games'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('a failed import reports the error and keeps the preview', (
      tester,
    ) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);
      await tester.tap(find.byKey(const Key('steam-import')));
      await tester.pump();

      opened.steam.stream.add(const SseError('Import failed'));
      await tester.pumpAndSettle();

      expect(find.text('Import failed'), findsOneWidget);
      expect(find.text('Import 3 games'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('the load button is off while an import runs', (tester) async {
      final opened = await open(tester);
      await loadLibrary(tester, opened);
      await tester.tap(find.byKey(const Key('steam-import')));
      await tester.pump();

      final load = tester.widget<ShelfButton>(
        find.byKey(const Key('steam-load')),
      );

      expect(load.onPressed, isNull);
      await opened.steam.stream.close();
      await tester.pumpAndSettle();
      await dismissToast(tester);
    });
  });

  group('the wishlist', () {
    testWidgets('loads the preview without playtime', (tester) async {
      final opened = await open(tester);

      opened.steam.wishlist = const [
        SteamRow(steamAppId: 10, title: 'Hades'),
        SteamRow(steamAppId: 11, title: 'Celeste'),
      ];
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('segmented-track')),
          matching: find.text('Wishlist'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pumpAndSettle();

      expect(opened.steam.calls, ['wishlist-preview']);
      expect(find.text('2 new games from your wishlist'), findsOneWidget);
      expect(find.textContaining(' h'), findsNothing);
    });

    testWidgets('shows the error of a failed load', (tester) async {
      final opened = await open(tester);
      opened.steam.wishlistError = const ApiException('Wishlist is private');

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('segmented-track')),
          matching: find.text('Wishlist'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pumpAndSettle();

      expect(find.text('Wishlist is private'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('imports, warns about skipped games and reads the account', (
      tester,
    ) async {
      final opened = await open(tester);
      opened.steam.wishlist = const [
        SteamRow(steamAppId: 10, title: 'Hades'),
        SteamRow(steamAppId: 11, title: 'Celeste'),
        SteamRow(steamAppId: 12, title: 'Portal'),
      ];
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('segmented-track')),
          matching: find.text('Wishlist'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pumpAndSettle();
      opened.settings.mutateAccount(
        (account) => SessionUser(
          name: account.name,
          email: account.email,
          setupCompleted: true,
          steamId: account.steamId,
          steamWishlistImportedAt: DateTime.utc(2026, 10, 10, 9),
        ),
      );

      await tester.tap(find.byKey(const Key('steam-import')));
      await tester.pump();
      expect(opened.steam.calls.last, 'import-wishlist [10, 11, 12]');
      opened.steam.stream.add(const SseDone(<Object?>[{}, {}]));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Imported 2 games from your Steam wishlist. 1 game could not be '
          'named by Steam right now and was left out - try the import again '
          'later',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('steam-wishlist-imported')), findsOneWidget);
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pump();
      expect(opened.steam.calls.last, 'library-preview');
      expect(find.byKey(const Key('segmented-track')), findsNothing);
      await dismissToast(tester);
    });

    testWidgets('the filter text survives a source switch', (tester) async {
      final opened = await open(tester);
      opened.steam.wishlist = const [SteamRow(steamAppId: 10, title: 'Hades')];
      await loadLibrary(tester, opened);
      await tester.enterText(find.byType(TextField).last, 'doom');
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('segmented-track')),
          matching: find.text('Wishlist'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pumpAndSettle();

      expect(find.text('No games match the filter.'), findsOneWidget);
    });

    testWidgets('after the first import it shows the date, not the option', (
      tester,
    ) async {
      await open(
        tester,
        user: SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          steamId: theo.steamId,
          steamWishlistImportedAt: DateTime.utc(2026, 10, 10, 9, 30),
          steamWishlistAutoSync: true,
        ),
      );

      expect(
        find.textContaining('Your Steam wishlist was imported on 10 Oct 2026'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Automatic wishlist sync is on'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('segmented-track')), findsNothing);
    });
  });

  group('the playtime sync button', () {
    Future<Opened> openLibraryPage(
      WidgetTester tester, {
      String steamId = '76561197960287930',
    }) {
      return open(
        tester,
        user: SessionUser(
          name: 'Theo',
          email: 'theo@example.com',
          setupCompleted: true,
          steamId: steamId,
        ),
        location: AppRoutes.library,
        backlog: FakeBacklogApi(entries: [game(1, 'Portal 2')]),
      );
    }

    testWidgets('is only there with a Steam ID', (tester) async {
      await openLibraryPage(tester, steamId: '');

      expect(find.byKey(const Key('steam-sync-button')), findsNothing);
    });

    testWidgets('syncs the playtimes with a progress ring and a toast', (
      tester,
    ) async {
      final opened = await openLibraryPage(tester);

      await tester.tap(find.byKey(const Key('steam-sync-button')));
      await tester.pump();
      expect(opened.steam.calls, ['sync-playtimes']);
      expect(find.byTooltip('Syncing playtimes...'), findsOneWidget);

      opened.steam.stream.add(const SseProgress(3, 10));
      await tester.pump();
      expect(find.byKey(const Key('steam-sync-ring')), findsOneWidget);
      expect(find.byTooltip('Syncing playtimes 3/10'), findsOneWidget);

      opened.steam.stream.add(const SseDone(<Object?>[{}, {}]));
      await tester.pumpAndSettle();

      expect(find.text('Synced 2 games from Steam'), findsOneWidget);
      expect(find.byKey(const Key('steam-sync-ring')), findsNothing);
      await dismissToast(tester);
    });

    testWidgets('says that Steam is up to date', (tester) async {
      final opened = await openLibraryPage(tester);

      await tester.tap(find.byKey(const Key('steam-sync-button')));
      await tester.pump();
      opened.steam.stream.add(const SseDone(<Object?>[]));
      await tester.pumpAndSettle();

      expect(find.text('Steam is already up to date'), findsOneWidget);
      await dismissToast(tester);
    });

    testWidgets('shows the error of a failed sync', (tester) async {
      final opened = await openLibraryPage(tester);

      await tester.tap(find.byKey(const Key('steam-sync-button')));
      await tester.pump();
      opened.steam.stream.add(const SseError('Steam is down'));
      await tester.pumpAndSettle();

      expect(find.text('Steam is down'), findsOneWidget);
      await dismissToast(tester);
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the Steam preview in $themeId', tags: 'golden', (
      tester,
    ) async {
      final opened = await open(tester);
      await tester.tap(find.byKey(const Key('steam-load')));
      await tester.pump();
      opened.steam.stream.add(
        SseDone([
          item(1091500, 'Cyberpunk 2077', playtime: 0),
          item(782330, 'DOOM Eternal', playtime: '3.2'),
          item(292030, 'The Witcher 3: Wild Hunt', playtime: 0),
          item(620, 'Portal 2', playtime: '11'),
          item(203160, 'Tomb Raider', playtime: 0),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomb Raider'));
      await tester.pump();
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(themeIdProvider.notifier)
          .select(themeId);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/steam_$themeId.png'),
      );
    });
  }
}
