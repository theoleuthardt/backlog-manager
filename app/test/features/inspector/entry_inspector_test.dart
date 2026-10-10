import 'dart:async';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/price_listings.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:backlog_manager/routing/router.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../data/fakes.dart';
import '../library/library_page_test.dart' show pumpLibrary;

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
  mainPlusExtraTime: 48,
  completionTime: 95,
  description: 'Defy the god of the dead.',
  trailerLink: 'https://www.youtube.com/watch?v=abcdefghijk',
  steamAppId: 1145360,
);

const celeste = BacklogEntry(
  id: 2,
  title: 'Celeste',
  genre: ['Platformer'],
  platform: ['PC'],
  status: 'Completed',
  completedAt: null,
);

String location(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

Future<({ProviderContainer container, FakeBacklogApi api})> openInspector(
  WidgetTester tester, {
  List<BacklogEntry> entries = const [hades, celeste],
  int id = 1,
  FakeBacklogApi? backlog,
  List<Override> overrides = const [],
}) async {
  final api = backlog ?? FakeBacklogApi(entries: entries);
  final container = await pumpLibrary(
    tester,
    api,
    height: 1500,
    overrides: overrides,
  );
  container.read(routerProvider).go('${AppRoutes.library}?entry=$id');
  await tester.pumpAndSettle();
  return (container: container, api: api);
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> afterAutosave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

void main() {
  group('opening', () {
    testWidgets('shows the game in the inspector slot', (tester) async {
      await openInspector(tester);

      expect(find.byKey(const Key('entry-inspector')), findsOneWidget);
      expect(find.byKey(const Key('inspector')), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('inspector-title'))).data,
        'Hades',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('inspector-subtitle'))).data,
        'Roguelike · Action · PC',
      );
      expect(find.text('Changes save automatically'), findsOneWidget);
    });

    testWidgets('closes itself for a game that does not exist', (tester) async {
      final app = await openInspector(tester, id: 99);

      expect(find.byKey(const Key('entry-inspector')), findsNothing);
      expect(location(app.container), AppRoutes.library);
    });

    testWidgets('the close button takes the game from the address', (
      tester,
    ) async {
      final app = await openInspector(tester);

      await tester.tap(find.byTooltip('Close inspector'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('entry-inspector')), findsNothing);
      expect(location(app.container), AppRoutes.library);
    });

    testWidgets('Esc closes it and clears the address', (tester) async {
      final app = await openInspector(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('entry-inspector')), findsNothing);
      expect(location(app.container), AppRoutes.library);
    });

    testWidgets('shows another game when the address changes', (tester) async {
      final app = await openInspector(tester);

      app.container.read(routerProvider).go('${AppRoutes.library}?entry=2');
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('inspector-title'))).data,
        'Celeste',
      );
    });
  });

  group('autosave', () {
    testWidgets('saves a changed playtime without a button', (tester) async {
      final app = await openInspector(tester);

      await tester.enterText(
        find.byKey(const Key('inspector-playtime')),
        '25.5',
      );
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      await afterAutosave(tester);

      expect(app.api.calls, contains('update 1 {playtime: 25.5}'));
      expect(find.text('All changes saved'), findsOneWidget);
    });

    testWidgets('sends rapid edits as one save of the last value', (
      tester,
    ) async {
      final app = await openInspector(tester);

      for (final text in ['2', '25', '250']) {
        await tester.enterText(
          find.byKey(const Key('inspector-playtime')),
          text,
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      await afterAutosave(tester);

      final saves = app.api.calls.where((c) => c.startsWith('update'));
      expect(saves, ['update 1 {playtime: 250.0}']);
    });

    testWidgets('a status change saves and keeps the inspector open', (
      tester,
    ) async {
      final app = await openInspector(tester);

      await tester.tap(find.byKey(const Key('status-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dropped').last);
      await afterAutosave(tester);

      expect(app.api.calls, contains('update 1 {status: Dropped}'));
      expect(find.byKey(const Key('entry-inspector')), findsOneWidget);
    });

    testWidgets('saves what was edited while a save was running', (
      tester,
    ) async {
      final gate = Completer<void>();
      final api = FakeBacklogApi(entries: const [hades])
        ..onUpdate = (id, update) async {
          if (update.playtime == 30) await gate.future;
        };
      await openInspector(tester, backlog: api);

      await tester.enterText(find.byKey(const Key('inspector-playtime')), '30');
      await tester.pump(const Duration(milliseconds: 900));
      await tester.enterText(find.byKey(const Key('inspector-playtime')), '31');
      await tester.pump(const Duration(milliseconds: 900));
      expect(api.calls.where((c) => c.startsWith('update')), hasLength(1));

      gate.complete();
      await afterAutosave(tester);

      expect(api.calls.where((c) => c.startsWith('update')), [
        'update 1 {playtime: 30.0}',
        'update 1 {playtime: 31.0}',
      ]);
    });

    testWidgets('a failed save shows "Not saved" and a toast', (tester) async {
      final api = FakeBacklogApi(entries: const [hades])
        ..onUpdate = (id, update) async =>
            throw const ApiException('Server unavailable');
      await openInspector(tester, backlog: api);

      await tester.enterText(find.byKey(const Key('inspector-playtime')), '40');
      await afterAutosave(tester);

      expect(find.text('Not saved'), findsOneWidget);
      expect(find.textContaining('Failed to save'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('closing saves the pending change at once', (tester) async {
      final app = await openInspector(tester);

      await tester.enterText(find.byKey(const Key('inspector-playtime')), '77');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Close inspector'));
      await tester.pumpAndSettle();

      expect(app.api.calls, contains('update 1 {playtime: 77.0}'));
    });

    testWidgets('a move to another status outside keeps the form in step', (
      tester,
    ) async {
      final app = await openInspector(tester);

      await app.container
          .read(entriesProvider(null).notifier)
          .moveToStatus(1, 'Completed');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('inspector-playtime')), '19');
      await afterAutosave(tester);

      final saves = app.api.calls.where((c) => c.startsWith('update'));
      expect(saves, [
        'update 1 {status: Completed}',
        'update 1 {playtime: 19.0}',
      ]);
    });
  });

  group('a change of the stored entry', () {
    testWidgets('shows a playtime that was synced while it is open', (
      tester,
    ) async {
      final app = await openInspector(tester);

      app.api.stored[1] = const BacklogEntry(
        id: 1,
        title: 'Hades',
        status: 'In Progress',
        playtime: 42,
      );
      await app.container.read(entriesProvider(null).notifier).refresh();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('inspector-playtime')))
            .controller!
            .text,
        '42',
      );
    });
  });

  group('the stat tiles', () {
    testWidgets('interest is clickable and clears on the current level', (
      tester,
    ) async {
      final app = await openInspector(tester);
      expect(find.text('6 / 10'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Interest: 6 of 10').first);
      await tester.pump();

      expect(find.byKey(const Key('inspector-interest')), findsOneWidget);
      expect(app.api.calls.where((c) => c.startsWith('update')), isEmpty);
    });

    testWidgets('the ownership switch changes the label and saves', (
      tester,
    ) async {
      final app = await openInspector(tester);
      expect(find.text('In my library'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Owned'));
      await tester.pump();
      expect(find.text('Not owned'), findsOneWidget);
      await afterAutosave(tester);

      expect(app.api.calls, contains('update 1 {owned: false}'));
    });

    testWidgets('shows the playtime of the partner in a shared space', (
      tester,
    ) async {
      await openInspector(
        tester,
        entries: const [
          BacklogEntry(
            id: 1,
            title: 'Hades',
            playtime: 4,
            partnerPlaytime: 6.5,
          ),
        ],
      );

      expect(find.text('Your partner: 6.5h'), findsOneWidget);
    });
  });

  group('the tabs', () {
    testWidgets('overview has the lists and the description', (tester) async {
      await openInspector(tester);

      expect(find.text('Defy the god of the dead.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Roguelike, Action'),
        'RPG',
      );
      await afterAutosave(tester);
    });

    testWidgets('progress shows the beat times against the playtime', (
      tester,
    ) async {
      await openInspector(tester);

      await openTab(tester, 'Progress');

      expect(find.text('HowLongToBeat - your 18h so far'), findsOneWidget);
      expect(find.text('22 h'), findsOneWidget);
      expect(find.text('48 h'), findsOneWidget);
      expect(find.text('95 h'), findsOneWidget);
    });

    testWidgets('progress shows two dashes for missing times', (tester) async {
      await openInspector(tester, id: 2);

      await openTab(tester, 'Progress');

      expect(find.text('--'), findsNWidgets(3));
    });

    testWidgets('review needs the status Completed', (tester) async {
      await openInspector(tester);
      await openTab(tester, 'Review');

      expect(
        find.text('Set the status to Completed to write a review'),
        findsOneWidget,
      );
      final reviewField = tester.widget<TextField>(
        find.byKey(const Key('inspector-review')),
      );
      expect(reviewField.enabled, isFalse);
    });

    testWidgets('a completed game can be reviewed and saves it', (
      tester,
    ) async {
      final app = await openInspector(tester, id: 2);
      await openTab(tester, 'Review');

      expect(find.text('Write your review here...'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('inspector-review')),
        'Lovely',
      );
      await afterAutosave(tester);

      expect(app.api.calls, contains('update 2 {review: Lovely}'));
    });

    testWidgets('the note saves for every status', (tester) async {
      final app = await openInspector(tester);
      await openTab(tester, 'Review');

      await tester.enterText(
        find.byKey(const Key('inspector-note')),
        'Try the hammer',
      );
      await afterAutosave(tester);

      expect(app.api.calls, contains('update 1 {note: Try the hammer}'));
    });

    testWidgets('trailer opens the video on YouTube', (tester) async {
      final opened = <Uri>[];
      await openInspector(
        tester,
        overrides: [urlOpenerProvider.overrideWithValue(opened.add)],
      );

      await openTab(tester, 'Trailer');
      await tester.tap(find.byKey(const Key('trailer-card')));
      await tester.pump();

      expect(opened, [
        Uri.parse('https://www.youtube.com/watch?v=abcdefghijk'),
      ]);
    });

    testWidgets('trailer says so when there is none', (tester) async {
      await openInspector(tester, id: 2);

      await openTab(tester, 'Trailer');

      expect(find.text('No trailer available for this game.'), findsOneWidget);
    });
  });

  group('the header', () {
    testWidgets('opens the price sheet of the game', (tester) async {
      final games = FakeGamesApi();
      games.onKeyShops = (_) async => const [
        KeyShopOffer(
          shop: 'RoyalCDKeys',
          title: 'Hades',
          price: 9,
          currency: 'EUR',
          url: 'https://royal.example/hades',
        ),
      ];
      await openInspector(
        tester,
        overrides: [gamesApiProvider.overrideWithValue(games)],
      );

      await tester.tap(find.byKey(const Key('inspector-prices')));
      await tester.pumpAndSettle();

      expect(find.text('Price'), findsOneWidget);
      expect(
        find.byKey(const Key('price-keyshop-RoyalCDKeys')),
        findsOneWidget,
      );
      expect(games.calls, containsAll(['price 1145360', 'keys Hades']));
    });

    testWidgets('update image applies an http address and saves it', (
      tester,
    ) async {
      final app = await openInspector(tester);

      await tester.tap(find.byKey(const Key('inspector-update-image')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '').last,
        'https://img.example/new.jpg',
      );
      await tester.tap(find.byKey(const Key('image-apply')));
      await tester.pumpAndSettle();
      await afterAutosave(tester);

      expect(
        app.api.calls,
        contains('update 1 {image_link: https://img.example/new.jpg}'),
      );
    });

    testWidgets('update image refuses an address that is not http', (
      tester,
    ) async {
      final app = await openInspector(tester);

      await tester.tap(find.byKey(const Key('inspector-update-image')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '').last,
        'javascript:alert(1)',
      );
      await tester.tap(find.byKey(const Key('image-apply')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter the address of an image (http or https).'),
        findsOneWidget,
      );
      expect(app.api.calls.where((c) => c.startsWith('update')), isEmpty);
    });
  });

  group('delete', () {
    testWidgets('asks first, then deletes and closes the inspector', (
      tester,
    ) async {
      final app = await openInspector(tester);

      await tester.tap(find.byKey(const Key('inspector-delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(app.api.calls.where((c) => c.startsWith('delete')), isEmpty);

      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();

      expect(app.api.calls, contains('delete 1'));
      expect(find.byKey(const Key('entry-inspector')), findsNothing);
      expect(location(app.container), AppRoutes.library);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  for (final themeId in ['shelfOled', 'light']) {
    testWidgets('golden: the inspector in $themeId', tags: 'golden', (
      tester,
    ) async {
      final app = await openInspector(tester);
      app.container.read(themeIdProvider.notifier).select(themeId);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/inspector_$themeId.png'),
      );
    });
  }
}
